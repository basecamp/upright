class Upright::Configuration
  # Global subdomain is always "app" - this is documented behavior
  GLOBAL_SUBDOMAIN = "app"

  # Core settings
  attr_accessor :service_name
  attr_accessor :user_agent
  attr_accessor :default_timeout

  # Storage paths
  attr_accessor :prometheus_dir
  attr_accessor :video_storage_dir
  attr_accessor :storage_state_dir
  attr_accessor :frozen_record_path

  # Probe and authenticator paths (for auto-loading app-specific code)
  attr_writer :probes_path
  attr_writer :authenticators_path

  # Playwright
  attr_accessor :playwright_server_url

  # Authentication
  attr_accessor :auth_provider
  attr_accessor :auth_options

  # Observability
  attr_accessor :otel_endpoint
  attr_accessor :prometheus_url
  attr_accessor :alert_webhook_url

  # Probe types
  attr_reader :probe_types

  # Probe result cleanup
  attr_accessor :stale_success_threshold
  attr_accessor :stale_failure_threshold
  attr_accessor :failure_retention_limit

  def initialize
    @service_name = "upright"
    @user_agent = "Upright/1.0"
    @default_timeout = 10.seconds

    @prometheus_dir = nil
    @video_storage_dir = nil
    @storage_state_dir = nil
    @frozen_record_path = nil
    @probes_path = nil
    @authenticators_path = nil

    @probe_types = Upright::ProbeTypeRegistry.new

    @playwright_server_url = ENV["PLAYWRIGHT_SERVER_URL"]
    @otel_endpoint = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"]

    @auth_provider = :static_credentials
    @auth_options = {}

    @stale_success_threshold = 24.hours
    @stale_failure_threshold = 30.days
    @failure_retention_limit = 20_000
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

  def video_storage_dir
    @video_storage_dir || Rails.root.join("storage", "playwright_videos")
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
    if Rails.env.production?
      { protocol: "https", host: "#{global_subdomain}.#{hostname}", domain: hostname }
    else
      { protocol: "http", host: "#{global_subdomain}.#{hostname}", port: ENV.fetch("PORT", 3000).to_i, domain: hostname }
    end
  end

  private
    def configure_allowed_hosts
      port_suffix = Rails.env.local? ? "(:\\d+)?" : ""
      Rails.application.config.hosts = [ /.*\.#{Regexp.escape(hostname)}#{port_suffix}/, /#{Regexp.escape(hostname)}#{port_suffix}/ ]
      Rails.application.config.action_dispatch.tld_length = 1
    end
end
