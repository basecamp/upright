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
    all.filter_map(&:current_outage)
  end

  def current_outage
    return if maintenance_active?

    live_status.then do |status|
      Upright::Service::Outage.new(service: self, status: status, started_at: current_outage_started_at) unless status == :operational
    end
  end

  def incidents
    Upright::Incident.public_facing.for_service(code)
  end

  def incident_history(page: nil)
    Upright::Service::IncidentHistory.for(self, page: page)
  end

  def incident_update_template(key)
    self[:incident_updates]&.fetch(key.to_s, nil)
  end

  DEFAULT_UPTIME_PROBE_TYPES = %w[ http ]

  # Probe types whose results decide this service's live status and daily
  # uptime: HTTP unless `uptime_probe_types` in services.yml says otherwise.
  # Other types bound to the service are still probed, rolled up and alerted on.
  # A type that isn't registered raises rather than matching nothing, since an
  # empty match would report the service operational.
  def uptime_probe_types
    types = Array(self[:uptime_probe_types]).map(&:to_s).presence || DEFAULT_UPTIME_PROBE_TYPES
    unknown = types - Upright.configuration.probe_types.types

    if unknown.any?
      raise Upright::ConfigurationError, "#{code}: uptime_probe_types #{unknown.join(", ")} not registered with config.probe_types"
    end

    types
  end

  # Rollups written before probe_type was recorded (July 2026) have none and
  # keep counting, so an upgrade doesn't drop history.
  def probe_rollups
    Upright::Rollups::ProbeRollup.where(probe_service: code, probe_type: [ *uptime_probe_types, nil ])
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
