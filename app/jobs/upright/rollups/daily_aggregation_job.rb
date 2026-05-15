class Upright::Rollups::DailyAggregationJob < Upright::ApplicationJob
  queue_as :default

  # Aggregates daily rollups for completed days only — today is still in progress
  # and is represented live by Service#live_status, so persisting a half-day
  # rollup would just produce a stale value the rest of the day.
  def perform(past: 1.day)
    (past.ago.to_date..Date.yesterday).each do |day|
      Upright::Rollups::ProbeRollup.aggregate_day(day)
    end
  end
end
