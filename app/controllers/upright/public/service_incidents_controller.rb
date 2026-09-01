class Upright::Public::ServiceIncidentsController < Upright::Public::BaseController
  def index
    service = Upright::Service.public_facing.find_by!(code: params[:service_code])
    @incident_history = service.incident_history(page: params[:page])
    expires_in 15.seconds, public: true
  end
end
