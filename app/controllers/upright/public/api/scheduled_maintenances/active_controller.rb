class Upright::Public::Api::ScheduledMaintenances::ActiveController < Upright::Public::Api::BaseController
  def index
    render json: status_json.active_maintenances
  end
end
