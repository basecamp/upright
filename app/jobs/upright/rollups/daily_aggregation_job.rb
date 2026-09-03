class Upright::Rollups::DailyAggregationJob < Upright::ApplicationJob
  queue_as :default

  # Aggregates daily rollups for completed days only — today is still in progress
  # and is represented live by Service#live_status, so persisting a half-day
  # rollup would just produce a stale value the rest of the day.
  def perform(past: 7.days)
    left_unwritten = (past.ago.to_date..Date.yesterday).flat_map do |day|
      Upright::Rollups::ProbeRollup.rollup_day(day)
    end

    Yabeda.upright_rollup_skipped_probes.set({}, left_unwritten.size)
  end
end
