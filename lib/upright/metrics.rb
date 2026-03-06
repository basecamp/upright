require "prometheus/client"
require "prometheus/client/data_stores/direct_file_store"
require "yabeda"

module Upright::Metrics
  class << self
    def configure
      setup_prometheus_store unless Rails.env.test?
      define_metrics
      Yabeda.configure!
    end

    def probe_duration_seconds
      Yabeda.upright_probe_duration_seconds
    end

    def probe_up
      Yabeda.upright_probe_up
    end

    def http_response_status
      Yabeda.upright_http_response_status
    end

    private
      def setup_prometheus_store
        prometheus_dir = Upright.configuration.prometheus_dir
        FileUtils.mkdir_p(prometheus_dir)

        Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: prometheus_dir.to_s)
      end

      def define_metrics
        current_site = Upright.current_site

        Yabeda.configure do
          default_tag :site_code, current_site&.code
          default_tag :site_city, current_site&.city
          default_tag :site_country, current_site&.country
          default_tag :site_geohash, current_site&.geohash
          default_tag :site_provider, current_site&.provider

          group :upright do
            gauge :probe_duration_seconds,
              comment: "Duration of each probe",
              aggregation: :max,
              tags: %i[type name probe_target probe_service alert_severity status]

            gauge :probe_up,
              comment: "Probe status (1 = up, 0 = down)",
              aggregation: :most_recent,
              tags: %i[type name probe_target probe_service alert_severity]

            gauge :http_response_status,
              comment: "HTTP response status code",
              aggregation: :max,
              tags: %i[name probe_target probe_service]
          end
        end
      end
  end
end
