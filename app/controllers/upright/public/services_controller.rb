class Upright::Public::ServicesController < Upright::Public::BaseController
  def index
    @services = Upright::Service.public_facing
  end
end
