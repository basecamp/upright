require "frozen_record"
require "prometheus/api_client"
require "opentelemetry-sdk"
require "opentelemetry-exporter-otlp"
require "typhoeus"
require "solid_queue"
require "mission_control/jobs"
require "omniauth"
require "omniauth_openid_connect"
require "omniauth/rails_csrf_protection"
require "omniauth/strategies/static_credentials"
require "propshaft"
require "importmap-rails"
require "turbo-rails"
require "stimulus-rails"
require "local_time"
require "geared_pagination"
require "yabeda/prometheus"
require "yabeda/puma/plugin"

require "upright/version"
require "upright/configuration"
require "upright/probe_type_registry"
require "upright/geohash"
require "upright/site"
require "upright/metrics"
require "upright/tracing"
require "upright/engine"

module Upright
  class ConfigurationError < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end
    alias_method :config, :configuration

    def configure
      yield(configuration)
    end

    def probe_types
      configuration.probe_types
    end

    def prometheus_client
      Prometheus::ApiClient.client(
        url: configuration.prometheus_url,
        options: { timeout: 30.seconds }
      )
    end

    def sites
      @sites ||= load_sites
    end

    def find_site(code)
      sites.find { |site| site.code.to_s == code.to_s }
    end

    def current_site
      find_site(ENV["SITE_SUBDOMAIN"]) || sites.first
    end

    def primary_site
      sites.find(&:primary?)
    end

    private
      def load_sites
        sites_config_path = Rails.root.join("config/sites.yml")

        if sites_config_path.exist?
          config = Rails.application.config_for(:sites)

          config[:sites].map.with_index do |site_config, index|
            Site.new(stagger_index: index, **site_config)
          end.tap { |sites| ensure_at_most_one_primary(sites) }
        else
          []
        end
      end

      # Two primaries means two hosts running the singleton jobs that write the
      # shared persistent database. None is how a host looks before it adopts
      # the flag, so that stays legal.
      def ensure_at_most_one_primary(sites)
        primaries = sites.select(&:primary?)

        if primaries.many?
          raise ConfigurationError, "sites.yml declares #{primaries.count} primary sites (#{primaries.map(&:code).join(', ')}); at most one may be primary"
        end
      end
  end
end
