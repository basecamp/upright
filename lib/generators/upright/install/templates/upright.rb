# See: https://github.com/basecamp/upright

Upright.configure do |config|
  config.service_name = "<%= Rails.application.class.module_parent_name.underscore %>"
  config.user_agent   = "<%= Rails.application.class.module_parent_name.underscore %>/1.0"
  config.hostname     = Rails.env.local? ? "<%= Rails.application.class.module_parent_name.underscore.dasherize %>.localhost" : "<%= Rails.application.class.module_parent_name.underscore.dasherize %>.com"

  # Playwright CLI path (defaults to "npx playwright", override with PLAYWRIGHT_CLI_PATH env var)
  # config.playwright_cli_path = "npx playwright"

  # Token authenticating machine callers: collectors writing metrics and jobs
  # reading a peer site's /prometheus and /alertmanager proxies. Randomly
  # generated at install time — every site must share the same value, so treat
  # it like any other secret when adding sites. Set the PROMETHEUS_OTLP_TOKEN
  # env var (already wired as a Kamal secret in config/deploy.yml) to rotate it
  # without editing this file.
  config.proxy_token = ENV.fetch("PROMETHEUS_OTLP_TOKEN", "<%= SecureRandom.hex(32) %>")

  # Viewer that trace artifacts link to, https://trace.playwright.dev by
  # default. Upright doesn't serve one: the viewer renders a trace's contents as
  # HTML in its own origin, so a viewer on this hostname would let a probe
  # artifact run script against the admin session, and Upright refuses a URL
  # under config.hostname for that reason.
  #
  # Following a link hands the viewer's origin a URL it can read for 24 hours.
  # Point this at a viewer you host to keep traces to yourself, or assign nil to
  # keep them download-only, for `npx playwright show-trace`.
  # config.trace_viewer_url = "https://traces.example.net/index.html"

  # OpenTelemetry endpoint
  # config.otel_endpoint = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"]

  # Authentication via OpenID Connect (Logto, Keycloak, Duo, Okta, etc.)
  # config.auth_provider = :openid_connect
  # config.auth_options = {
  #   issuer: ENV["OIDC_ISSUER"],
  #   client_id: ENV["OIDC_CLIENT_ID"],
  #   client_secret: ENV["OIDC_CLIENT_SECRET"]
  # }

  # Register custom probe types (built-in types: http, playwright, smtp, traceroute)
  # config.probe_types.register :ftp_file, name: "FTP File", icon: "📂"
end
