class Upright::Public::Api::ComponentsController < Upright::Public::Api::BaseController
  def index
    render json: status_json.components
  end
end
