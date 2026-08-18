class Upright::Service < FrozenRecord::Base
  include Upright::Services::LiveStatus
  include Upright::Services::MaintenanceStatus

  def self.file_path
    Upright.configuration.services_path.to_s
  end

  scope :public_facing, -> { where(public: true) }

  # The public status page passes `incidents: Upright::Incident.public_facing`
  # so internal-only incidents and maintenances never color the public banner.
  def self.overall_status(incidents: Upright::Incident.all)
    probe_statuses = all.reject(&:maintenance_active?).map(&:live_status)
    worst = Upright::Status.worst(probe_statuses + incidents.active_statuses)
    worst == :operational && incidents.planned.active.any? ? :maintenance : worst
  end

  def self.by_history(past: 90.days)
    all.to_h { |service| [ service, service.daily_status_history(past: past) ] }
  end

  def self.degraded
    all.filter_map do |service|
      next if service.maintenance_active?
      status = service.live_status
      unless status == :operational
        { service: service, status: status, started_at: service.current_outage_started_at }
      end
    end
  end

  def probe_rollups
    Upright::Rollups::ProbeRollup.where(probe_service: code)
  end

  def uptime_for(day)
    probe_rollups.where(period_start: day.beginning_of_day).minimum(:uptime_fraction)
  end

  def daily_uptime(past: 90.days)
    probe_rollups
      .where(period_start: past.ago.beginning_of_day..)
      .group(:period_start)
      .minimum(:uptime_fraction)
  end

  # Unified day-by-day view: past days from ProbeRollup, today from live
  # Prometheus state, missing days as no-data. Callers iterate without caring
  # which source backs each entry.
  def daily_status_history(past: 90.days)
    rollup_by_day = daily_uptime(past: past)

    (past.ago.to_date.next_day..Date.current).map do |date|
      if date == Date.current
        DailyStatus.new(date: date, status: live_status)
      else
        fraction = rollup_by_day[date.beginning_of_day]
        DailyStatus.new(
          date: date,
          status: Upright::Status.for(fraction),
          uptime_fraction: fraction
        )
      end
    end
  end
end
