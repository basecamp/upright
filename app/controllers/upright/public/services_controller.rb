class Upright::Public::ServicesController < Upright::Public::BaseController
  def index
    @services = Upright::Service.public_facing
    expires_in 15.seconds, public: true
  end
end
