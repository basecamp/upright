class Upright::Public::Api::IncidentsController < Upright::Public::Api::BaseController
  def index
    @incidents = public_incidents.limit(INCIDENT_LIMIT)
  end
end
