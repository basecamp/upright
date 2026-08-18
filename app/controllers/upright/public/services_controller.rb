class Upright::Public::ServicesController < Upright::Public::BaseController
  def index
    @services = Upright::Service.public_facing
    @overall_status = @services.overall_status(incidents: Upright::Incident.public_facing)
    @active_incidents = Upright::Incident.public_facing.reactive.active.order(starts_at: :desc)
    @active_maintenances = Upright::Maintenance.public_facing.active.order(:starts_at)
    @upcoming_maintenances = Upright::Maintenance.public_facing.upcoming.order(:starts_at)
    expires_in 15.seconds, public: true
  end
end
