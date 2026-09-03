module Upright::Services::MaintenanceStatus
  extend ActiveSupport::Concern

  def active_maintenance
    Upright::Maintenance.active.for_service(code).first
  end

  def maintenance_active?
    active_maintenance.present?
  end

  def upcoming_maintenances
    Upright::Maintenance.upcoming.for_service(code).order(:starts_at)
  end

  def active_incidents
    Upright::Incident.reactive.active.for_service(code)
  end
end
