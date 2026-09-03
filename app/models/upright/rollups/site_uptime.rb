class Upright::Rollups::SiteUptime
  UPTIME_METRIC   = "upright:probe_uptime_daily"
  COVERAGE_METRIC = "upright:probe_down_fraction"

  attr_reader :site, :day

  def initialize(site, on:)
    @site, @day = site, on
  end

  def probe_uptimes
    uptime_series.map do |metric, uptime|
      Upright::Rollups::ProbeUptime.new(
        probe_name:        metric[:name],
        probe_type:        metric[:type],
        probe_target:      metric[:probe_target],
        probe_service:     metric[:probe_service].presence,
        uptime_fraction:   uptime,
        coverage_fraction: coverage_for(metric)
      )
    end
  rescue StandardError => error
    nothing_reported because: error
  end

  private
    def nothing_reported(because:)
      Rails.logger.warn "[upright] #{site.code} Prometheus unavailable for the #{day} rollup: #{because.class}: #{because.message}"
      []
    end

    def uptime_series
      series_for uptime_query
    end

    def coverage_for(metric)
      [ coverage.fetch(probe_key_for(metric), 0.0), 1.0 ].min
    end

    def coverage
      @coverage ||= series_for(coverage_query).to_h do |metric, samples|
        [ probe_key_for(metric), samples / expected_samples ]
      end
    end

    def series_for(query)
      values_by_metric site.prometheus_client.query(query: query, time: queried_at.iso8601)
    end

    def values_by_metric(response)
      Array(response.deep_symbolize_keys[:result]).map do |series|
        [ series[:metric], series.dig(:value, 1).to_f ]
      end
    end

    def queried_at
      [ day.end_of_day, Time.current ].min
    end

    def expected_samples
      1.day / Upright.configuration.rollup_evaluation_interval
    end

    def probe_key_for(metric)
      metric.values_at(:name, :type, :probe_target)
    end

    def uptime_query
      %(#{UPTIME_METRIC}{environment="#{Rails.env}"})
    end

    def coverage_query
      %(count_over_time(#{COVERAGE_METRIC}{environment="#{Rails.env}"}[1d]))
    end
end
