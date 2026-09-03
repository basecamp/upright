class Upright::Public::ServicesController < Upright::Public::BaseController
  def index
    @status_page = Upright::Service::StatusPage.current
    expires_in 15.seconds, public: true
  end
end
