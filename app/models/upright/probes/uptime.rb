class Upright::Probes::Uptime
  class << self
    def all
      for_type(nil)
    end

    def for_type(probe_type)
      results = Upright.prometheus_client.query_range(
        query: query(probe_type),
        start: 30.days.ago.iso8601,
        end:   Time.current.iso8601,
        step:  "86400s" # 1 day
      ).deep_symbolize_keys

      results[:result].map { |result| Summary.new(result) }.sort
    end

    private
      def query(probe_type)
        "min by (name, type, probe_target) (upright:probe_uptime_daily#{label_selector(probe_type)})"
      end

      def label_selector(probe_type)
        matchers = [ "alert_severity!=\"\"", "environment=\"#{Rails.env}\"" ]
        matchers << "type=\"#{probe_type}\"" if probe_type.present?
        "{#{matchers.join(",")}}"
      end
  end
end
