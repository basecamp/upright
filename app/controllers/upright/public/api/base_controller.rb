class Upright::Public::Api::BaseController < Upright::Public::BaseController
  skip_before_action :serve_html_for_unsupported_formats
  before_action :require_public_status_json_enabled
  before_action { expires_in CACHE_TTL, public: true }
  before_action { response.set_header "Access-Control-Allow-Origin", "*" }

  private
    def require_public_status_json_enabled
      render_not_found unless Upright.configuration.public_status_json_enabled
    end

    def status_json
      Upright::Service::StatusPage::JsonFormat.new(Upright::Service::StatusPage.current, url: helpers.public_status_base_url)
    end
end
