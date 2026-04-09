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

    def sites
      @sites ||= load_sites
    end

    def find_site(code)
      sites.find { |site| site.code.to_s == code.to_s }
    end

    def current_site
      find_site(ENV["SITE_SUBDOMAIN"]) || sites.first
    end

    private
      def load_sites
        sites_config_path = Rails.root.join("config/sites.yml")

        if sites_config_path.exist?
          config = Rails.application.config_for(:sites)

          config[:sites].map.with_index do |site_config, index|
            Site.new(stagger_index: index, **site_config)
          end
        else
          []
        end
      end
  end
end
