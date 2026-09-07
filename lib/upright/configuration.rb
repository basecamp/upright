class Upright::Configuration
  # Global subdomain is always "app" - this is documented behavior
  GLOBAL_SUBDOMAIN = "app"

  # Public status pages live at status.<hostname>; custom CNAMEs match by subdomain.
  PUBLIC_STATUS_SUBDOMAIN = "status"

  DEFAULT_TRACE_VIEWER_URL = "https://trace.playwright.dev/"

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

  attr_reader :trace_viewer_url

  # Authentication
  attr_accessor :auth_provider
  attr_accessor :auth_options

  # Observability
  attr_accessor :otel_endpoint
  attr_accessor :prometheus_url
  attr_accessor :alert_webhook_url

  # Machine credentials. Both come from the environment by default and both are
  # required outside development and test; see #verify_machine_tokens.
  attr_writer :otlp_token
  attr_writer :metrics_read_token

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

    self.trace_viewer_url = ENV.fetch("TRACE_VIEWER_URL", DEFAULT_TRACE_VIEWER_URL)

    @public_status_enabled = false
    @public_status_custom_domains = []
    @public_stylesheets = nil
  end

  def trace_viewer_url=(url)
    @trace_viewer_url = url.presence
    host = trace_viewer_uri&.host

    if @trace_viewer_url && (host.nil? || admin_domain?(host))
      raise Upright::ConfigurationError, "config.trace_viewer_url must be an http(s) URL outside #{@hostname}"
    end
  end

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

  # Presented by collectors writing metrics through the OTLP route. It authorizes
  # nothing else.
  def otlp_token
    @otlp_token || ENV["PROMETHEUS_OTLP_TOKEN"]
  end

  # Presented by peer sites and tooling reading the /prometheus and /alertmanager
  # proxies with GET or HEAD. It cannot write metrics.
  def metrics_read_token
    @metrics_read_token || ENV["METRICS_READ_TOKEN"]
  end

  # 0.4 had one token for both. Refuse it rather than pick a side.
  def proxy_token=(_value)
    raise Upright::ConfigurationError, "config.proxy_token was split into config.otlp_token (PROMETHEUS_OTLP_TOKEN) and config.metrics_read_token (METRICS_READ_TOKEN); see UPGRADING.md"
  end

  # A blank token would compare every bearer value against "", so a deployed
  # environment must have both, and they must differ or the split is undone.
  def verify_machine_tokens
    missing = { "PROMETHEUS_OTLP_TOKEN" => otlp_token, "METRICS_READ_TOKEN" => metrics_read_token }.select { |_, token| token.blank? }.keys

    if missing.any?
      raise Upright::ConfigurationError, "#{missing.join(" and ")} must be set outside development and test (config.otlp_token and config.metrics_read_token)"
    end

    if ActiveSupport::SecurityUtils.secure_compare(otlp_token.to_s, metrics_read_token.to_s)
      raise Upright::ConfigurationError, "PROMETHEUS_OTLP_TOKEN and METRICS_READ_TOKEN must differ: the same value would let a collector read metrics and a reader write them"
    end
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
    def trace_viewer_uri
      url = URI(@trace_viewer_url.to_s)
      url if url.is_a?(URI::HTTP) && url.host.present?
    rescue URI::InvalidURIError
      nil
    end

    # DNS is case-insensitive and tolerates a trailing dot, so compare folded.
    def admin_domain?(host)
      return false if @hostname.blank?

      host = host.downcase.chomp(".")
      admin = @hostname.downcase

      host == admin || host.end_with?(".#{admin}")
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
