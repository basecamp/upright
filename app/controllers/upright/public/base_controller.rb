# TODO: Throttle the public status routes (e.g. with Rack::Attack) if the 15s
# Prometheus result cache (Upright::Services::LiveStatus::CACHE_TTL) proves
# insufficient against anonymous request bursts. rack-attack isn't a dependency
# yet, so we lean on caching for now.
class Upright::Public::BaseController < ActionController::Base
  layout "upright/public"

  helper :all
  protect_from_forgery with: :exception

  private
    def default_url_options
      Rails.application.routes.default_url_options
    end
end
