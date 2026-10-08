# TODO: Throttle the public status routes (e.g. with Rack::Attack) if the 15s
# Prometheus result cache (Upright::Services::LiveStatus::CACHE_TTL) proves
# insufficient against anonymous request bursts. rack-attack isn't a dependency
# yet, so we lean on caching for now.
class Upright::Public::BaseController < ActionController::Base
  CACHE_TTL = 15.seconds

  layout "upright/public"

  helper :all
  protect_from_forgery with: :exception

  before_action :serve_html_for_unsupported_formats

  rescue_from ActiveRecord::RecordNotFound, FrozenRecord::RecordNotFound, with: :render_not_found

  private
    def default_url_options
      Rails.application.routes.default_url_options
    end

    # A CDN in front of the page may cache by URL alone, so a 406 for one client's
    # Accept header must never be what the next visitor receives.
    def serve_html_for_unsupported_formats
      request.format = :html unless request.format.html? || request.format.rss?
    end

    def render_not_found
      expires_in CACHE_TTL, public: true

      if (page = Rails.public_path.join("404.html")).exist?
        render file: page, status: :not_found, layout: false, content_type: "text/html"
      else
        head :not_found
      end
    end
end
