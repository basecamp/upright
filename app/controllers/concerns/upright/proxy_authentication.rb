module Upright::ProxyAuthentication
  extend ActiveSupport::Concern

  # A forwarded path may only be a path: no authority (`//host`), no traversal,
  # nothing outside the RFC 3986 path character set. This is what stops a request
  # like `/prometheus//169.254.169.254/…` from retargeting Faraday at another host
  # (SSRF, CVE-2026-25765).
  SAFE_UPSTREAM_PATH = %r{\A/[A-Za-z0-9\-._~!$&'()*+,;=:@/]*\z}
  MAX_UPSTREAM_QUERY = 4096

  # Destructive/admin upstream endpoints automation must never reach with a token
  # (Prometheus `/-/reload`, `/-/quit`, Alertmanager admin under `/-/`). The
  # embedded same-origin UI can still use them on the session path.
  TOKEN_DENIED_PREFIXES = %w[ /-/ ].freeze

  included do
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

    # CSRF gate for the browser (session-cookie) path. Rails token CSRF is skipped
    # on the proxies because the embedded Prometheus/Alertmanager UIs make
    # same-origin requests that can't carry an authenticity token, so we gate with
    # Fetch-Metadata / Origin instead (CVE-2026-67990). Automation authenticates
    # with a bearer token and is out of scope here; a missing/invalid token is not
    # exempt — it simply falls through to a 401 at authentication.
    def block_cross_site_session_requests
      head :forbidden if request.authorization.blank? && cross_site_request?
    end

    def cross_site_request?
      site = request.headers["Sec-Fetch-Site"]
      origin = request.headers["Origin"]

      if site.present?
        # Only same-origin (the embedded UI) and user-initiated `none` (a typed
        # URL or bookmark) are allowed. same-site is refused too: a sibling on the
        # same registrable domain (evil.example.com vs ams.upright.example.com) is
        # same-site, and a top-level navigation from it would otherwise carry the
        # Lax cookie into a forged proxy request.
        !site.in?(%w[ same-origin none ])
      elsif origin.present?
        origin != request.base_url
      else
        # No Fetch-Metadata and no Origin: treat as cross-site and refuse. Every
        # current browser sends Sec-Fetch-Site (and the embedded same-origin UI
        # does too), so only a pre-2023 client omits it; failing closed keeps a
        # header-less cross-site GET from riding the Lax session cookie.
        true
      end
    end

    # Validate the operator-controlled proxy path before it reaches Faraday, and
    # cap the query so an operator query can't be turned into a nested-params DoS.
    # Returns the safe "path[?query]" to forward, or nil to reject.
    def sanitized_upstream_path(raw)
      path, separator, query = raw.to_s.partition("?")
      path = "/" if path.empty?

      # Reject an authority override (//host), any dot-segment (`.`/`..`),
      # characters outside the path set, and ANY percent-encoding in the path.
      # Faraday resolves the path with URI#merge, which collapses `.`/`..` and
      # decodes escapes, so `/./-/reload` or a double-encoded `/%252d%252freload`
      # would otherwise slip an authority override or a denied `/-/` prefix past
      # these checks and be normalized on the upstream.
      if path.start_with?("//") || path.match?(%r{(?:\A|/)\.\.?(?:/|\z)}) || path.include?("%") || !path.match?(SAFE_UPSTREAM_PATH) || query.length > MAX_UPSTREAM_QUERY
        nil
      else
        "#{path}#{separator}#{query}"
      end
    end

    # Belt-and-suspenders after path validation: resolve the forwarded path the
    # same way Faraday's Connection does (URI#merge) and require that it still
    # lands on the configured upstream host and port. This catches an authority
    # override (`//host`) even if the character-level check above ever misses one.
    def upstream_host_ok?(base_url, forward)
      base = URI.parse(base_url)
      built = base.merge(forward)
      built.host == base.host && built.port == base.port
    rescue URI::Error
      false
    end

    # A token may read through the proxy but not drive destructive or
    # state-changing upstream endpoints; those stay on the same-origin session UI.
    def token_forbidden_path?(path)
      request.authorization.present? &&
        ((!request.get? && !request.head?) || path.start_with?(*TOKEN_DENIED_PREFIXES))
    end
end
