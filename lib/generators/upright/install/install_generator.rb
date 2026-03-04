module Upright
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install Upright engine into your application"

      def set_ruby_version
        ruby_version = RUBY_VERSION
        create_file ".ruby-version", "#{ruby_version}\n"
        create_file "mise.toml", <<~TOML
          [tools]
          ruby = "#{ruby_version}"
        TOML
      end

      def copy_initializers
        template "upright.rb", "config/initializers/upright.rb"
        template "omniauth.rb", "config/initializers/omniauth.rb"
      end

      def copy_sites_config
        template "sites.yml", "config/sites.yml"
      end

      def create_probe_directories
        empty_directory "probes"
        empty_directory "probes/authenticators"
        template "http_probes.yml", "probes/http_probes.yml"
        template "smtp_probes.yml", "probes/smtp_probes.yml"
        template "traceroute_probes.yml", "probes/traceroute_probes.yml"
      end

      def copy_observability_configs
        template "prometheus.yml", "config/prometheus/prometheus.yml"
        template "upright.rules.yml", "config/prometheus/rules/upright.rules.yml"
        template "alertmanager.yml", "config/alertmanager/alertmanager.yml"
        template "otel_collector.yml", "config/otel_collector.yml"
        template "development_prometheus.yml", "config/prometheus/development/prometheus.yml"
        template "development_alertmanager.yml", "config/alertmanager/development/alertmanager.yml"
      end

      def copy_dev_services
        template "docker-compose.yml", "docker-compose.yml"
      end

      def copy_deploy_config
        template "deploy.yml", "config/deploy.yml"
      end

      def copy_puma_config
        template "puma.rb", "config/puma.rb"
      end

      def install_solid_queue
        rails_command "solid_queue:install"
      end

      def add_queue_database
        gsub_file "config/database.yml",
          "development:\n  <<: *default\n  database: storage/development.sqlite3",
          "development:\n  primary:\n    <<: *default\n    database: storage/development.sqlite3\n  queue:\n    <<: *default\n    database: storage/development_queue.sqlite3\n    migrations_paths: db/queue_migrate"

        gsub_file "config/database.yml",
          "test:\n  <<: *default\n  database: storage/test.sqlite3",
          "test:\n  primary:\n    <<: *default\n    database: storage/test.sqlite3\n  queue:\n    <<: *default\n    database: storage/test_queue.sqlite3\n    migrations_paths: db/queue_migrate"
      end

      def copy_recurring_config
        template "recurring.yml", "config/recurring.yml", force: true
      end

      def add_jobs_to_procfile
        procfile = File.join(destination_root, "Procfile.dev")
        if File.exist?(procfile)
          unless File.read(procfile).include?("jobs:")
            append_to_file "Procfile.dev", "jobs: OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES bin/rails solid_queue:start\n"
          end
        else
          create_file "Procfile.dev", <<~PROCFILE
            web: bin/rails server -b '0.0.0.0' -p ${PORT:-3000}
            jobs: OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES bin/rails solid_queue:start
          PROCFILE
        end
      end

      def add_routes
        route 'mount Upright::Engine => "/", as: :upright'
      end

      def install_active_storage
        rails_command "active_storage:install"
      end

      def configure_javascript
        append_to_file "app/javascript/application.js", 'import "upright/application"'
      end

      def show_post_install_message
        say ""
        say "Upright has been installed!", :green
        say ""
        say "Next steps:"
        say "  1. Prepare the database: bin/rails db:prepare"
        say "  2. Configure your servers in config/deploy.yml"
        say "  3. Configure sites in config/sites.yml"
        say "  4. Add probes in probes/*.yml"
        say "  5. Set ADMIN_PASSWORD env var (default: upright)"
        say ""
        say "For production, review config/initializers/upright.rb and update:"
        say "  config.hostname = \"example.com\""
        say ""
        say "Start dev services (Prometheus, Alertmanager, Playwright):"
        say "  docker compose up -d"
        say ""
        say "Start the development server with: bin/dev"
        say ""
        say "Then access your app at:"
        say "  http://app.#{app_name}.localhost:3000"
        say ""
      end

      private
        def app_name
          Rails.application.class.module_parent_name.underscore.dasherize
        end

        def app_domain
          "#{app_name}.example.com"
        end
    end
  end
end
