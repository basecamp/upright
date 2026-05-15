class Upright::Rollups::ProbeRollup < Upright::ApplicationRecord
  self.table_name = "upright_rollups_probe_rollups"

  enum :status, Upright::Status::VALUES, default: :operational

  before_save :derive_status_from_uptime

  scope :for_period, ->(range) { where(period_start: range) }
  scope :for_service, ->(code) { where(probe_service: code) if code.present? }
  scope :for_probe, ->(name) { where(probe_name: name) if name.present? }

  PROMETHEUS_METRIC = "upright:probe_uptime_daily".freeze

  def self.rollup_day(day)
    fetch_uptime_for(day).each do |probe_uptime|
      find_or_create_by(probe_name: probe_uptime.fetch(:probe_name), period_start: day.beginning_of_day) do |rollup|
        rollup.probe_service   = probe_uptime[:probe_service]
        rollup.uptime_fraction = probe_uptime.fetch(:uptime_fraction)
      end
    end
  end

  def self.fetch_uptime_for(day)
    query_time = [ day.end_of_day, Time.current ].min

    response = prometheus_client.query(query: PROMETHEUS_METRIC, time: query_time.iso8601).deep_symbolize_keys

    Array(response[:result]).map do |series|
      {
        probe_name:      series.dig(:metric, :name),
        probe_service:   series.dig(:metric, :probe_service).presence,
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

  private
    def derive_status_from_uptime
      self.status = Upright::Status.for(uptime_fraction)
    end
end
