class Upright::ApplicationController < ActionController::Base
  include Upright::SubdomainScoping
  include Upright::Authentication

  helper :all
  protect_from_forgery with: :exception

  private
    def default_url_options
      Rails.application.routes.default_url_options.except(:host)
    end
end
