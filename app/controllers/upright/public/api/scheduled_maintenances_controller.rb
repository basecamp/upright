class Upright::Public::Api::ScheduledMaintenancesController < Upright::Public::Api::BaseController
  def index
    render json: status_json.scheduled_maintenances
  end
end
