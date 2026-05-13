class Upright::Rollups::ServiceRollup < Upright::ApplicationRecord
  include Upright::Rollups::Status

  self.table_name = "upright_rollups_service_rollups"

  scope :for_period, ->(range) { where(period_start: range) }
  scope :for_service, ->(code) { where(service_code: code) if code.present? }

  def self.aggregate_day(day)
    Upright::Rollups::ProbeRollup
      .where(period_start: day.beginning_of_day)
      .where.not(probe_service: [ nil, "" ])
      .group(:probe_service)
      .minimum(:uptime_fraction)
      .each do |service_code, uptime_fraction|
        upsert_day(day:, service_code:, uptime_fraction:)
      end
  end

  def self.upsert_day(day:, service_code:, uptime_fraction:)
    rollup = find_or_initialize_by(service_code:, period_start: day.beginning_of_day)
    rollup.uptime_fraction = uptime_fraction
    rollup.status = status_for(uptime_fraction)
    rollup.save!
  end

  def service
    Upright::Service.find_by(code: service_code)
  end
end
