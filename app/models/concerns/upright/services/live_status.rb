module Upright::Services::LiveStatus
  extend ActiveSupport::Concern

  OUTAGE_LOOKBACK = 24.hours

  def live_status
    Upright::Status.for(live_up_fraction)
  end

  # Earliest moment of the current outage, or nil if the service is currently
  # clear OR the outage predates OUTAGE_LOOKBACK. Callers should treat nil on a
  # non-operational service as "longer than the live window."
  def current_outage_started_at(now: Time.current)
    history = live_down_history(now: now)
    last_clear = history.rindex { |_ts, value| value.to_f == 0 }

    if last_clear && last_clear < history.length - 1
      Time.zone.at(history[last_clear + 1].first.to_f)
    end
  end

  private
    def live_up_fraction
      1 - live_down_fraction
    end

    def live_down_fraction
      response = Upright.prometheus_client.query(
        query: live_down_query
      ).deep_symbolize_keys
      response.dig(:result, 0, :value, 1).to_f
    end

    def live_down_history(now:)
      response = Upright.prometheus_client.query_range(
        query: live_down_query,
        start: (now - OUTAGE_LOOKBACK).iso8601,
        end:   now.iso8601,
        step:  "300s"
      ).deep_symbolize_keys
      response.dig(:result, 0, :values) || []
    end

    def live_down_query
      matchers = [ %(probe_service="#{code}") ]
      matchers << %(environment="#{Rails.env}") unless Rails.env.local?
      %(max(upright:probe_down_fraction{#{matchers.join(",")}}) or vector(0))
    end
end
