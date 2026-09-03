class Upright::Probes::Status
  class << self
    def for_type(probe_type)
      results = Upright.prometheus_client.query_range(
        query: query(probe_type),
        start: 30.minutes.ago.iso8601,
        end:   Time.current.iso8601,
        step:  "30s"
      ).deep_symbolize_keys

      build_probes(results[:result])
    end

    private
      def query(probe_type)
        "upright_probe_up#{label_selector(probe_type)}"
      end

      def label_selector(probe_type)
        matchers = [ "alert_severity!=\"\"", "environment=\"#{Rails.env}\"" ]
        matchers << "type=\"#{probe_type}\"" if probe_type.present?
        "{#{matchers.join(",")}}"
      end

      def build_probes(results)
        grouped = results.group_by { |r| Probe.key_for(**r[:metric]) }

        grouped.map do |(_name, _type, _target), series|
          site_statuses = series.map do |s|
            SiteStatus.new(
              site_code: s[:metric][:site_code],
              site_city: s[:metric][:site_city],
              values: s[:values]
            )
          end

          Probe.new(
            name: _name,
            type: _type,
            probe_target: _target,
            site_statuses: site_statuses
          )
        end.sort
      end
  end
end
