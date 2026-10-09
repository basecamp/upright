class Upright::Service::StatusPage
  attr_reader :services, :active_incidents, :active_maintenances, :upcoming_maintenances

  def self.current
    services = Upright::Service.public_facing

    new services: services,
      active_incidents: Upright::Incident.public_facing.reactive.active.order(starts_at: :desc).preload(:affected_services, :updates),
      active_maintenances: Upright::Maintenance.public_facing.active.order(:starts_at).preload(:affected_services, :updates),
      upcoming_maintenances: Upright::Maintenance.public_facing.upcoming.order(:starts_at).preload(:affected_services, :updates)
  end

  def initialize(services:, active_incidents:, active_maintenances:, upcoming_maintenances:)
    @services = services
    @active_incidents = active_incidents
    @active_maintenances = active_maintenances
    @upcoming_maintenances = upcoming_maintenances
  end

  def overall_status
    services.overall_status(incidents: Upright::Incident.public_facing)
  end

  def outages
    services.degraded
  end

  def active_events
    active_incidents.to_a + active_maintenances.to_a
  end

  def service_histories
    services.by_history
  end
end
