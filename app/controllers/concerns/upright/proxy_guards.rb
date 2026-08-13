module Upright::ProxyGuards
  extend ActiveSupport::Concern

  included do
    prepend_before_action :block_cross_site_session_requests
  end

  private
    # CSRF gate for the browser (session-cookie) path. Rails token CSRF is skipped
    # on the proxies because the embedded Prometheus/Alertmanager UIs make
    # same-origin requests that can't carry an authenticity token, so we gate with
    # Fetch-Metadata / Origin instead (CVE-2026-67990). The token-authenticated
    # OTLP ingest endpoint skips this gate and stays on its own 401 path.
    def block_cross_site_session_requests
      head :forbidden if cross_site_request?
    end

    def cross_site_request?
      site = request.headers["Sec-Fetch-Site"]
      origin = request.headers["Origin"]

      if site.present?
        # Same-origin (the embedded UI) and user-initiated `none` (typed URL /
        # bookmark) are fine; a same-site *top-level GET navigation* is an admin
        # moving between our own subdomains. Everything else — cross-site, and any
        # same-site sub-resource or write — is refused.
        !(site.in?(%w[ same-origin none ]) ||
          (site == "same-site" && request.get? && request.headers["Sec-Fetch-Mode"] == "navigate"))
      elsif origin.present?
        origin != request.base_url
      else
        # No Fetch-Metadata and no Origin (a pre-Fetch-Metadata browser): fail
        # closed on state-changing methods, allow plain reads.
        !request.get? && !request.head?
      end
    end
end
