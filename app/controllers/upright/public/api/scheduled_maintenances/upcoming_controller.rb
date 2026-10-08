class Upright::Public::Api::ScheduledMaintenances::UpcomingController < Upright::Public::Api::BaseController
  def index
    render json: status_json.upcoming_maintenances
  end
end
