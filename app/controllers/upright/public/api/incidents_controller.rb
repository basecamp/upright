class Upright::Public::Api::IncidentsController < Upright::Public::Api::BaseController
  def index
    render json: status_json.incidents
  end
end
