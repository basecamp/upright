class Upright::Public::ServicesController < Upright::Public::BaseController
  def index
    @status_page = Upright::Service::StatusPage.current
    expires_in CACHE_TTL, public: true
  end
end
