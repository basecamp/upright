class Upright::Public::Api::BaseController < Upright::Public::BaseController
  INCIDENT_LIMIT = 50

  skip_before_action :serve_html_for_unsupported_formats
  before_action :require_public_status_json_enabled
  before_action { expires_in CACHE_TTL, public: true }
  before_action { response.set_header "Access-Control-Allow-Origin", "*" }

  private
    def require_public_status_json_enabled
      render_not_found unless Upright.configuration.public_status_json_enabled
    end

    def public_incidents
      Upright::Incident.public_facing.reactive.order(starts_at: :desc).preload(:updates, :affected_services)
    end

    def public_maintenances
      Upright::Maintenance.public_facing.order(starts_at: :desc).preload(:updates, :affected_services)
    end
end
