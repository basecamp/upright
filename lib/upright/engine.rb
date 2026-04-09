class Upright::Engine < ::Rails::Engine
  isolate_namespace Upright

  # Add concerns to autoload paths
  config.autoload_paths << root.join("app/models/concerns")

  # Session store configuration
  initializer "upright.session_store", before: :load_config_initializers do |app|
    app.config.session_store :cookie_store,
      key: "_upright_session",
      domain: :all,
      same_site: :lax,
      secure: Rails.env.production?,
      expire_after: 24.hours
  end

  config.after_initialize do
    url_options = Upright.configuration.default_url_options
    Rails.application.routes.default_url_options = url_options
    Upright::Engine.routes.default_url_options = url_options
  end

  initializer "upright.solid_queue", before: :set_configs_for_current_railties do |app|
    unless Rails.env.test?
      app.config.active_job.queue_adapter = :solid_queue
      app.config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue } }
    end
  end

  # Configure Mission Control to use engine's authenticated controller
  initializer "upright.mission_control" do
    MissionControl::Jobs.base_controller_class = "Upright::ApplicationController"
    MissionControl::Jobs.http_basic_auth_enabled = false
  end

  # Configure acronym inflections for autoloading
  initializer "upright.inflections", before: :bootstrap_hook do
    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "HTTP"
      inflect.acronym "SMTP"
    end
  end

  config.generators do |g|
    g.test_framework :minitest
  end

  initializer "upright.assets" do |app|
    app.config.assets.paths << root.join("app/javascript")
  end

  initializer "upright.importmap", before: "importmap" do |app|
    if defined?(Importmap::Engine)
      app.config.importmap.paths << root.join("config/importmap.rb")
      app.config.importmap.cache_sweepers << root.join("app/javascript")
    end
  end

  initializer "upright.probe_types", before: :load_config_initializers do
    Upright.config.probe_types.register :http, name: "HTTP", icon: "🌐"
    Upright.config.probe_types.register :playwright, name: "Playwright", icon: "🎭"
    Upright.config.probe_types.register :smtp, name: "SMTP", icon: "✉️"
    Upright.config.probe_types.register :traceroute, name: "Traceroute", icon: "🛤️"
  end

  initializer "upright.frozen_record" do
    FrozenRecord::Base.base_path = Upright.configuration.frozen_record_path
  end

  initializer "upright.yabeda" do
    Upright::Metrics.configure
  end

  initializer "upright.opentelemetry" do
    Upright::Tracing.configure
  end

  # Start metrics server for Solid Queue worker process
  initializer "upright.solid_queue_metrics" do
    SolidQueue.on_start do
      ENV["PROMETHEUS_EXPORTER_PORT"] ||= Rails.env.local? ? "9395" : "9394"
      ENV["PROMETHEUS_EXPORTER_LOG_REQUESTS"] = "false"
      Yabeda::Prometheus::Exporter.start_metrics_server!
    end
  end

  initializer "upright.duration_extension" do
    ActiveSupport::Duration.class_eval do
      def in_ms
        (to_f * 1000).to_i
      end
    end
  end

  # Silence Ethon's verbose debug output to stdout
  # By default, Ethon's debug callback prints curl verbose messages which pollutes logs
  initializer "upright.ethon" do
    Ethon::Easy::Callbacks.module_eval do
      def debug_callback
        @debug_callback ||= proc { |handle, type, data, size, udata|
          message = data.read_string(size)
          @debug_info.add(type, message)
          0
        }
      end
    end
  end

  # Allow host app to override views
  config.to_prepare do
    Upright::ApplicationController.helper Rails.application.helpers
  end

  # Print available URLs in development
  config.after_initialize do
    if Rails.env.development? && defined?(Rails::Server)
      url_options = Upright.configuration.default_url_options
      hostname = url_options[:domain]
      port = url_options[:port]
      protocol = url_options[:protocol]

      puts ""
      puts "Upright is running at:"
      puts "  Global: #{protocol}://#{Upright.configuration.global_subdomain}.#{hostname}:#{port}"
      Upright.sites.each do |site|
        puts "  #{site.city || site.code}:  #{protocol}://#{site.code}.#{hostname}:#{port}"
      end
      puts ""
    end
  end

  # Auto-load Playwright probes and authenticators from configured paths
  config.after_initialize do
    # Define namespaces for app-specific probes and authenticators
    module ::Probes
      module Playwright
      end
    end

    module ::Playwright
      module Authenticator
      end
    end

    probes_path = Upright.configuration.probes_path
    if probes_path && Dir.exist?(probes_path)
      Dir[probes_path.join("*_probe.rb")].sort.each { |file| require file }
    end

    authenticators_path = Upright.configuration.authenticators_path
    if authenticators_path && Dir.exist?(authenticators_path)
      Dir[authenticators_path.join("*.rb")].sort.each { |file| require file }
    end
  end

  # Add engine migrations to host app
  initializer "upright.migrations" do |app|
    unless app.root.to_s == root.join("test/dummy").to_s
      config.paths["db/migrate"].expanded.each do |expanded_path|
        app.config.paths["db/migrate"] << expanded_path
      end
    end
  end
end
