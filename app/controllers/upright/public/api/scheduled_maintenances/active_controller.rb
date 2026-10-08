class Upright::Public::Api::ScheduledMaintenances::ActiveController < Upright::Public::Api::BaseController
  def index
    @maintenances = public_maintenances.active
  end
end
