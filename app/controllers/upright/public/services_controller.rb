class Upright::Public::StatusController < Upright::Public::BaseController
  def show
    @services = Upright::Service.public_facing
  end
end
