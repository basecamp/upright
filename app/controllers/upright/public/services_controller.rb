class Upright::Public::ServicesController < Upright::Public::BaseController
  def index
    @services = Upright::Service.public_facing
    @overall_status = @services.overall_status(incidents: Upright::Incident.public_facing)
    @active_incidents = Upright::Incident.public_facing.reactive.active.order(starts_at: :desc)
    @active_maintenances = Upright::Maintenance.public_facing.active.order(:starts_at)
    @upcoming_maintenances = Upright::Maintenance.public_facing.upcoming.order(:starts_at)
    expires_in 15.seconds, public: true
  end

  def show
    @service = Upright::Service.public_facing.find_by!(code: params[:code])
    @active = Upright::Incident.public_facing.reactive.active.for_service(@service.code).preload(:updates)
    set_page_and_extract_portion_from Upright::Incident.public_facing.for_service(@service.code).past.reorder(nil).preload(:updates),
      ordered_by: { starts_at: :desc }
    @past = @page.records
    expires_in 15.seconds, public: true
  end
end
