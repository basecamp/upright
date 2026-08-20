class Upright::Configuration
  # Global subdomain is always "app" - this is documented behavior
  GLOBAL_SUBDOMAIN = "app"

  # Public status pages live at status.<hostname>; custom CNAMEs match by subdomain.
  PUBLIC_STATUS_SUBDOMAIN = "status"

  # Core settings
  attr_accessor :service_name
  attr_accessor :user_agent
  attr_accessor :default_timeout

  # Storage paths
  attr_accessor :prometheus_dir
  attr_accessor :video_storage_dir
  attr_accessor :recording_base_dir
  attr_accessor :storage_state_dir
  attr_accessor :frozen_record_path

  # Probe and authenticator paths (for auto-loading app-specific code)
  attr_writer :probes_path
  attr_writer :authenticators_path

  # Public status page services definition (env-overridable, like probes_path)
  attr_writer :services_path

  # Playwright
  attr_accessor :playwright_cli_path

  # Origin serving the Playwright Trace Viewer, e.g.
  # "https://traces.example.net/index.html". Upright doesn't serve the viewer:
  # it renders trace contents as HTML in its own origin, so an admin-origin
  # viewer turns a probe artifact into same-origin script. Unset means traces
  # are download-only.
  attr_reader :trace_viewer_url

  # Authentication
  attr_accessor :auth_provider
  attr_accessor :auth_options

  # Observability
  attr_accessor :otel_endpoint
  attr_accessor :prometheus_url
  attr_accessor :alert_webhook_url

  attr_writer :proxy_token

  attr_writer :rollup_minimum_coverage
  attr_writer :rollup_evaluation_interval

  # Probe types
  attr_reader :probe_types

  # Probe result cleanup
  attr_accessor :stale_success_threshold
  attr_accessor :stale_failure_threshold
  attr_accessor :failure_retention_limit

  # Public status pages
  attr_accessor :public_status_enabled
  attr_reader :public_status_custom_domains

  # Extra stylesheets host apps layer on top of the engine's for the public
  # status page (theming, branding). Logical asset names, loaded last so their
  # :root overrides win the cascade.
  attr_writer :public_stylesheets

  def initialize
    @service_name = "upright"
    @user_agent = "Upright/1.0"
    @default_timeout = 10.seconds

    @prometheus_dir = nil
    @video_storage_dir = nil
    @recording_base_dir = nil
    @storage_state_dir = nil
    @frozen_record_path = nil
    @probes_path = nil
    @authenticators_path = nil
    @services_path = nil

    @probe_types = Upright::ProbeTypeRegistry.new

    @playwright_cli_path = ENV.fetch("PLAYWRIGHT_CLI_PATH", "npx playwright")
    @otel_endpoint = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"]
    @prometheus_url = nil

    @auth_provider = :static_credentials
    @auth_options = {}

    @stale_success_threshold = 24.hours
    @stale_failure_threshold = 30.days
    @failure_retention_limit = 20_000

    @trace_viewer_url = nil

    @public_status_enabled = false
    @public_status_custom_domains = []
    @public_stylesheets = nil
  end

  # A trace renders in the viewer's origin, so a viewer on Upright's own hostname
  # would put it back on the admin origin.
  def trace_viewer_url=(url)
    @trace_viewer_url = url.presence

    unless isolated_trace_viewer?
      raise Upright::ConfigurationError, "config.trace_viewer_url must be an http(s) URL outside #{@hostname}"
    end
  end

  # The viewer's origin on its own, for the CORS header that lets it read a
  # trace. Nil when no viewer is configured.
  def trace_viewer_origin
    trace_viewer_uri&.then do |url|
      "#{url.scheme}://#{url.host}#{":#{url.port}" unless url.port == url.default_port}"
    end
  end

  def public_status_subdomain
    PUBLIC_STATUS_SUBDOMAIN
  end

  def public_stylesheets
    Array(@public_stylesheets)
  end

  def public_status_custom_domains=(domains)
    @public_status_custom_domains = Array(domains)
    configure_allowed_hosts if @hostname
  end

  def global_subdomain
    GLOBAL_SUBDOMAIN
  end

  def site_subdomains
    Upright.sites.map { |site| site.code.to_s }
  end

  def prometheus_dir
    @prometheus_dir || Rails.root.join("tmp", "prometheus")
  end

  def prometheus_url
    @prometheus_url || ENV.fetch("PROMETHEUS_URL", "http://localhost:9090")
  end

  def proxy_token
    @proxy_token || ENV["PROMETHEUS_OTLP_TOKEN"]
  end

  def rollup_minimum_coverage
    @rollup_minimum_coverage || 0.9
  end

  def rollup_evaluation_interval
    @rollup_evaluation_interval || 30.seconds
  end

  def video_storage_dir
    @video_storage_dir || Rails.root.join("storage", "playwright_videos")
  end

  def recording_base_dir
    @recording_base_dir || Rails.root.join("storage", "playwright_recordings")
  end

  def storage_state_dir
    @storage_state_dir || Rails.root.join("storage", "playwright_storage_states")
  end

  def frozen_record_path
    @frozen_record_path || Rails.root.join("config", "probes")
  end

  def probes_path
    @probes_path || Rails.root.join("probes")
  end

  def services_path
    @services_path || Rails.root.join("config", "services.yml")
  end

  def authenticators_path
    @authenticators_path || Rails.root.join("probes", "authenticators")
  end

  def hostname=(value)
    @hostname = value
    configure_allowed_hosts
  end

  def hostname
    @hostname
  end

  def default_url_options
    if Rails.env.local?
      { protocol: "http", host: "#{global_subdomain}.#{hostname}", port: ENV.fetch("PORT", 3000).to_i, domain: hostname }
    else
      { protocol: "https", host: "#{global_subdomain}.#{hostname}", domain: hostname }
    end
  end

  private
    # URI::HTTPS subclasses URI::HTTP, so this admits both and rejects anything
    # without a scheme and host — a hostless value would otherwise leave
    # #trace_viewer_origin with no origin to send.
    def trace_viewer_uri
      url = URI(@trace_viewer_url.to_s)
      url if url.is_a?(URI::HTTP) && url.host.present?
    rescue URI::InvalidURIError
      nil
    end

    def isolated_trace_viewer?
      return true if @trace_viewer_url.blank?
      return false if trace_viewer_uri.nil?
      return true if @hostname.blank?

      # DNS is case-insensitive and tolerates a trailing dot; the guard has to be
      # too, or an equivalent spelling of the admin host passes it.
      host = trace_viewer_uri.host.downcase.chomp(".")
      admin = @hostname.downcase

      host != admin && !host.end_with?(".#{admin}")
    end

    def configure_allowed_hosts
      port_suffix = Rails.env.local? ? "(:\\d+)?" : ""
      hosts = [ /.*\.#{Regexp.escape(hostname)}#{port_suffix}/, /#{Regexp.escape(hostname)}#{port_suffix}/ ]
      Array(@public_status_custom_domains).each do |domain|
        hosts << /\A#{Regexp.escape(domain)}#{port_suffix}\z/
      end
      Rails.application.config.hosts = hosts
      Rails.application.config.action_dispatch.tld_length = 1
    end
end
