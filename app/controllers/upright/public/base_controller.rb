class Upright::Public::BaseController < ActionController::Base
  helper :all
  protect_from_forgery with: :exception

  private
    def default_url_options
      Rails.application.routes.default_url_options
    end
end
