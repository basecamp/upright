module Upright::Services::LiveStatus
  extend ActiveSupport::Concern

  OUTAGE_LOOKBACK = 24.hours

  def live_status
    Upright::Rollups::ProbeRollup.status_for(1 - live_down_fraction)
  end

  # Earliest moment of the current outage, or nil if the service is currently
  # clear OR the outage predates OUTAGE_LOOKBACK. Callers should treat nil on a
  # non-operational service as "longer than the live window."
  def current_outage_started_at(now: Time.current)
    history = live_down_history(now: now)
    return nil if history.empty?

    last_clear = history.rindex { |_ts, value| value.to_f == 0 }
    return nil if last_clear.nil?
    return nil if last_clear == history.length - 1

    Time.zone.at(history[last_clear + 1].first.to_f)
  end

  private
    def live_down_fraction
      response = self.class.prometheus_client.query(
        query: "max(upright:probe_down_fraction{probe_service=\"#{code}\"}) or vector(0)"
      ).deep_symbolize_keys
      response.dig(:result, 0, :value, 1).to_f
    end

    def live_down_history(now:)
      response = self.class.prometheus_client.query_range(
        query: "max(upright:probe_down_fraction{probe_service=\"#{code}\"}) or vector(0)",
        start: (now - OUTAGE_LOOKBACK).iso8601,
        end:   now.iso8601,
        step:  "300s"
      ).deep_symbolize_keys
      response.dig(:result, 0, :values) || []
    end

  class_methods do
    def prometheus_client
      Prometheus::ApiClient.client(
        url: ENV.fetch("PROMETHEUS_URL", "http://localhost:9090"),
        options: { timeout: 30.seconds }
      )
    end
  end
end
