class Upright::Rollups::DailyAggregationJob < Upright::ApplicationJob
  queue_as :default

  def perform(lookback: 1.day)
    (lookback.ago.to_date..Date.today).each do |day|
      Upright::Rollups::ProbeRollup.aggregate_day(day)
    end
  end
end
