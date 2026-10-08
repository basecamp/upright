class Upright::Public::Api::StatusesController < Upright::Public::Api::BaseController
  def show
    @status_page = Upright::Service::StatusPage.current
  end
end
