class Upright::Public::Api::Incidents::UnresolvedController < Upright::Public::Api::BaseController
  def index
    @incidents = public_incidents.unresolved
  end
end
