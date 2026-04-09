# See: https://github.com/basecamp/upright

Upright.configure do |config|
  config.service_name = "<%= Rails.application.class.module_parent_name.underscore %>"
  config.user_agent   = "<%= Rails.application.class.module_parent_name.underscore %>/1.0"
  config.hostname     = Rails.env.local? ? "<%= Rails.application.class.module_parent_name.underscore.dasherize %>.localhost" : "<%= Rails.application.class.module_parent_name.underscore.dasherize %>.com"

  # Playwright browser server URL
  # config.playwright_server_url = ENV["PLAYWRIGHT_SERVER_URL"]

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
