class Upright::Public::Api::SummariesController < Upright::Public::Api::BaseController
  def show
    @status_page = Upright::Service::StatusPage.current
    @incidents = public_incidents.unresolved
    @maintenances = public_maintenances.unresolved
  end
end
