class Upright::Rollups::ProbeRollup < Upright::PersistentRecord
  self.table_name = "upright_rollups_probe_rollups"

  enum :status, Upright::Status::VALUES, default: :operational

  before_save :derive_status_from_uptime

  scope :for_period, ->(range) { where(period_start: range) }
  scope :for_service, ->(code) { where(probe_service: code) if code.present? }
  scope :for_probe, ->(name) { where(probe_name: name) if name.present? }

  def self.rollup_day(day)
    uptime = Upright::Rollups::DailyUptime.new(day)

    uptime.covered.each { |probe_uptime| record probe_uptime, on: day }

    uptime.gappy.tap do |left_unwritten|
      Rails.logger.warn thin_coverage_warning(left_unwritten, on: day) if left_unwritten.any?
    end
  end

  def self.thin_coverage_warning(probe_uptimes, on:)
    "[upright] #{on}: left #{probe_uptimes.size} rollups unwritten below #{Upright.configuration.rollup_minimum_coverage} coverage (#{probe_uptimes.map(&:probe_name).uniq.join(', ')})"
  end
  private_class_method :thin_coverage_warning

  def self.record(probe_uptime, on:)
    rollup = find_or_initialize_by(
      probe_name:   probe_uptime.probe_name,
      probe_type:   probe_uptime.probe_type,
      probe_target: probe_uptime.probe_target,
      period_start: on.beginning_of_day
    )

    rollup.probe_service   = probe_uptime.probe_service
    rollup.uptime_fraction = probe_uptime.uptime_fraction
    rollup.save!
  end

  def self.export_metrics
    if (last_run = maximum(:created_at))
      Yabeda.upright_rollup_last_run_timestamp_seconds.set({}, last_run.to_i)
    end
  end

  def probe_key
    [ probe_name, probe_type, probe_target ]
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
