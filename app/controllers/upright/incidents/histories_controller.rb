# Redirects /incidents/history to the incidents page, keeping its filters.
class Upright::Incidents::HistoriesController < Upright::ApplicationController
  def show
    redirect_to incidents_path(request.query_parameters.slice("kind", "service", "q", "page")), status: :moved_permanently
  end
end
