class Upright::Rollups::ProbeRollup < Upright::ApplicationRecord
  self.table_name = "upright_rollups_probe_rollups"

  enum :status, Upright::Status::VALUES, default: :operational

  scope :for_period, ->(range) { where(period_start: range) }
  scope :for_service, ->(code) { where(probe_service: code) if code.present? }
  scope :for_probe, ->(name) { where(probe_name: name) if name.present? }

  PROMETHEUS_METRIC = "upright:probe_uptime_daily".freeze

  def self.aggregate_day(day)
    fetch_uptime_for(day).each do |sample|
      upsert_day(
        day:,
        probe_name: sample.fetch(:name),
        probe_service: sample[:probe_service],
        uptime_fraction: sample.fetch(:uptime_fraction)
      )
    end
  end

  def self.upsert_day(day:, probe_name:, probe_service:, uptime_fraction:)
    rollup = find_or_initialize_by(probe_name:, period_start: day.beginning_of_day)
    rollup.probe_service = probe_service
    rollup.uptime_fraction = uptime_fraction
    rollup.status = Upright::Status.for(uptime_fraction)
    rollup.save!
  end

  def self.fetch_uptime_for(day)
    query_time = [ day.end_of_day, Time.current ].min

    response = prometheus_client.query(query: PROMETHEUS_METRIC, time: query_time.iso8601).deep_symbolize_keys

    Array(response[:result]).map do |series|
      {
        name: series.dig(:metric, :name),
        probe_service: series.dig(:metric, :probe_service).presence,
        uptime_fraction: series.dig(:value, 1).to_f
      }
    end
  end

  def self.prometheus_client
    Prometheus::ApiClient.client(
      url: ENV.fetch("PROMETHEUS_URL", "http://localhost:9090"),
      options: { timeout: 30.seconds }
    )
  end

  def service
    Upright::Service.find_by(code: probe_service) if probe_service.present?
  end

  def uptime_percentage
    if uptime_fraction.present?
      (uptime_fraction * 100).round(4)
    end
  end
end
