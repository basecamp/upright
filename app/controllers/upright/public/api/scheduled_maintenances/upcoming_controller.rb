class Upright::Public::Api::ScheduledMaintenances::UpcomingController < Upright::Public::Api::BaseController
  def index
    @maintenances = public_maintenances.upcoming
  end
end
