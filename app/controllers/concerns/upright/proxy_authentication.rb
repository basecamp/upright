module Upright::ProxyAuthentication
  extend ActiveSupport::Concern

  included do
    # Rails' token CSRF is skipped on the proxies because the embedded
    # Prometheus/Alertmanager UIs issue same-origin requests that can't carry a
    # Rails authenticity token. Guard the session-cookie path instead with a
    # Fetch-Metadata / Origin check so a cross-site request can't ride the
    # victim's Lax session cookie into upstream write APIs (CVE-2026-67990).
    prepend_before_action :block_cross_site_session_requests
  end

  private
    def authenticate_user
      if request.authorization.present?
        authenticate_proxy_token
      else
        super
      end
    end

    def authenticate_proxy_token
      authenticate_or_request_with_http_token do |token|
        ActiveSupport::SecurityUtils.secure_compare(token, Upright.configuration.proxy_token.to_s)
      end
    end

    # Automation authenticates with a bearer token and is exempt; only the
    # browser session-cookie path is forgeable, and a genuine same-origin call
    # from the embedded UI is never cross-site.
    def block_cross_site_session_requests
      head :forbidden if request.authorization.blank? && cross_site_request?
    end

    def cross_site_request?
      if (site = request.headers["Sec-Fetch-Site"]).present?
        !site.in?(%w[ same-origin same-site none ])
      elsif (origin = request.headers["Origin"]).present?
        origin != request.base_url
      else
        false
      end
    end
end
