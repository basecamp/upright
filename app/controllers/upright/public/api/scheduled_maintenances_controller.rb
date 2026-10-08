class Upright::Public::Api::ScheduledMaintenancesController < Upright::Public::Api::BaseController
  def index
    @maintenances = public_maintenances.limit(INCIDENT_LIMIT)
  end
end
