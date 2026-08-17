module Upright::ProxyAuthentication
  extend ActiveSupport::Concern

  # A forwarded path may only be a path: no authority (`//host`), no traversal,
  # nothing outside the RFC 3986 path character set. The upstream host and port
  # never come from the request (see #upstream_url), so this isn't the SSRF
  # control — it keeps a normalizing hop from rewriting the path into a denied
  # one, and keeps junk out of the upstream request.
  SAFE_UPSTREAM_PATH = %r{\A/[A-Za-z0-9\-._~!$&'()*+,;=:@/]*\z}

  # Cap the query we relay upstream. Rack's query parser already protects *us*
  # from a nested-params bomb (it enforces param count, depth and bytesize limits
  # before the action runs); this is about not handing an unbounded query to
  # Prometheus or Alertmanager.
  MAX_UPSTREAM_QUERY = 4096

  # Destructive/admin upstream endpoints automation must never reach with a token
  # (Prometheus `/-/reload`, `/-/quit`, Alertmanager admin under `/-/`). The
  # embedded same-origin UI can still use them on the session path.
  TOKEN_DENIED_PREFIXES = %w[ /-/ ]

  included do
    prepend_before_action :block_cross_site_session_requests
  end

  private
    def authenticate_user
      if proxy_token_provided?
        authenticate_proxy_token
      else
        super
      end
    end

    # Specifically "carries a bearer token", not "carries any Authorization
    # header": a `Basic` header belongs on the session path, and shouldn't buy an
    # exemption from the cross-site gate on its way to a 401.
    def proxy_token_provided?
      ActionController::HttpAuthentication::Token.token_and_options(request).present?
    end

    def authenticate_proxy_token
      authenticate_or_request_with_http_token do |token|
        ActiveSupport::SecurityUtils.secure_compare(token, Upright.configuration.proxy_token.to_s)
      end
    end

    # The proxies can't demand an authenticity token: the embedded Prometheus and
    # Alertmanager UIs post from JS we don't render, so there's no token to embed.
    # Rather than skipping Rails' verification, widen what counts as verified — a
    # valid token, a bearer token (not an ambient credential, so a cross-site page
    # can't attach one), or same-origin provenance. Cross-site requests are
    # already refused by #block_cross_site_session_requests; leaving verification
    # in the chain means removing that gate can't quietly leave the proxies with
    # no CSRF defence at all.
    def verified_request?
      super || proxy_token_provided? || !cross_site_request?
    end

    # CSRF gate for the browser (session-cookie) path: nothing in Action Pack
    # reads Fetch-Metadata, so we gate on it here (CVE-2026-67990). Unlike Rails'
    # token verification this covers GET too, because a proxied GET can reach a
    # state-changing upstream endpoint. Automation authenticates with a bearer
    # token and is out of scope; a missing/invalid token is not exempt — it simply
    # falls through to a 401 at authentication.
    def block_cross_site_session_requests
      head :forbidden if !proxy_token_provided? && cross_site_request?
    end

    def cross_site_request?
      site = request.headers["Sec-Fetch-Site"]

      if site.present?
        # Only same-origin (the embedded UI) and user-initiated `none` (a typed
        # URL or bookmark) are allowed. same-site is refused too: a sibling on the
        # same registrable domain (evil.example.com vs ams.upright.example.com) is
        # same-site, and a top-level navigation from it would otherwise carry the
        # Lax cookie into a forged proxy request.
        !site.in?(%w[ same-origin none ])
      elsif request.origin.present?
        # The same comparison Rails makes in #valid_request_origin?. A sandboxed
        # iframe or a cross-origin redirect sends `Origin: null`, which never
        # equals base_url and so lands here as cross-site.
        request.origin != request.base_url
      else
        # No Fetch-Metadata and no Origin: treat as cross-site and refuse. Every
        # current browser sends Sec-Fetch-Site (and the embedded same-origin UI
        # does too), so only a pre-2023 client omits it; failing closed keeps a
        # header-less cross-site GET from riding the Lax session cookie.
        true
      end
    end

    # Build the upstream URL for a forwarded request. Scheme, host and port always
    # come from the configured upstream, so no forwarded path can retarget Faraday
    # at another host — an authority override like
    # `/prometheus//169.254.169.254/latest/meta-data` (SSRF, CVE-2026-25765) can't
    # survive being assigned as a path component. Returns the URI to forward, or
    # nil to reject.
    def upstream_url(base_url, raw)
      path, _separator, query = raw.to_s.partition("?")
      path = "/" if path.empty?

      if safe_upstream_path?(path) && query.length <= MAX_UPSTREAM_QUERY
        URI.parse(base_url).tap do |url|
          url.path = path
          url.query = query.presence
        end
      end
    rescue URI::Error
      nil
    end

    # Faraday and the upstream both normalize and percent-decode the path, so
    # `/./-/reload` or a double-encoded `/%252d%252freload` would arrive at a
    # denied `/-/` endpoint if we only checked the literal prefix. Reject any
    # dot-segment, any percent-encoding, and anything outside the path set.
    # Rack::Utils.valid_path? runs first: it screens null bytes and broken
    # encoding, which would otherwise raise out of the regexp match.
    def safe_upstream_path?(path)
      Rack::Utils.valid_path?(path) &&
        !path.start_with?("//") &&
        !path.match?(%r{(?:\A|/)\.\.?(?:/|\z)}) &&
        !path.include?("%") &&
        path.match?(SAFE_UPSTREAM_PATH)
    end

    # A token may read through the proxy but not drive destructive or
    # state-changing upstream endpoints; those stay on the same-origin session UI.
    def token_forbidden_path?(path)
      proxy_token_provided? &&
        ((!request.get? && !request.head?) || path.start_with?(*TOKEN_DENIED_PREFIXES))
    end
end
