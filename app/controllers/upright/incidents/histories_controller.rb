# The history is the incidents page now. This keeps old links, filters included, working.
class Upright::Incidents::HistoriesController < Upright::ApplicationController
  def show
    redirect_to incidents_path(request.query_parameters), status: :moved_permanently
  end
end
