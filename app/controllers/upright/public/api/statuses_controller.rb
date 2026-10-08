class Upright::Public::Api::StatusesController < Upright::Public::Api::BaseController
  def show
    render json: status_json.overall_status
  end
end
