class Upright::Public::Api::SummariesController < Upright::Public::Api::BaseController
  def show
    render json: status_json.summary
  end
end
