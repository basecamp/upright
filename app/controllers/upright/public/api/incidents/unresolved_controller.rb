class Upright::Public::Api::Incidents::UnresolvedController < Upright::Public::Api::BaseController
  def index
    render json: status_json.unresolved_incidents
  end
end
