class Upright::Rollups::DailyAggregationJob < Upright::ApplicationJob
  queue_as :default

  def perform(days_back: 1)
    (0..days_back).each do |offset|
      day = Date.current - offset
      Upright::Rollups::ProbeRollup.aggregate_day(day)
      Upright::Rollups::ServiceRollup.aggregate_day(day)
    end
  end
end
