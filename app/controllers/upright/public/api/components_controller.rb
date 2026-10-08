class Upright::Public::Api::ComponentsController < Upright::Public::Api::BaseController
  def index
    @services = Upright::Service.public_facing
  end
end
