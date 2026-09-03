class Upright::Public::IncidentsController < Upright::Public::BaseController
  def show
    @incident = Upright::Incident.public_facing.find(params[:id])
    expires_in 15.seconds, public: true
  end
end
