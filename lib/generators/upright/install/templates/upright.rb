# See: https://github.com/basecamp/upright

Upright.configure do |config|
  config.service_name = "<%= Rails.application.class.module_parent_name.underscore %>"
  config.user_agent   = "<%= Rails.application.class.module_parent_name.underscore %>/1.0"
  config.hostname     = Rails.env.local? ? "<%= Rails.application.class.module_parent_name.underscore.dasherize %>.localhost" : "<%= Rails.application.class.module_parent_name.underscore.dasherize %>.com"

  # Playwright CLI path (defaults to "npx playwright", override with PLAYWRIGHT_CLI_PATH env var)
  # config.playwright_cli_path = "npx playwright"

  # Machine credentials, read from the environment. Both are required outside
  # development and test, they must differ, and the app refuses to boot without
  # them.
  #
  #   PROMETHEUS_OTLP_TOKEN  Presented by collectors writing metrics through
  #                          /prometheus/api/v1/otlp/v1/metrics. Authorizes
  #                          nothing else.
  #   METRICS_READ_TOKEN     Presented by peer sites and tooling reading the
  #                          /prometheus and /alertmanager proxies. Cannot write.
  #
  # Generate each with `bin/rails secret`, store them as Kamal secrets (listed in
  # config/deploy.yml and .kamal/secrets) and give every site the same two
  # values. They do not belong in this file or anywhere else in git.
  # config.otlp_token         = ENV["PROMETHEUS_OTLP_TOKEN"]
  # config.metrics_read_token = ENV["METRICS_READ_TOKEN"]

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
