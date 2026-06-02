require "test_helper"

class Upright::Rollups::DailyAggregationJobTest < ActiveSupport::TestCase
  test "aggregates yesterday and earlier — today is still in progress" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      yesterday = Date.yesterday

      Upright::Rollups::ProbeRollup.expects(:rollup_day).with(yesterday).once
      Upright::Rollups::ProbeRollup.expects(:rollup_day).with(Date.current).never

      Upright::Rollups::DailyAggregationJob.new.perform
    end
  end

  test "past: 0.days skips aggregation entirely since today is excluded" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      Upright::Rollups::ProbeRollup.expects(:rollup_day).never

      Upright::Rollups::DailyAggregationJob.new.perform(past: 0.days)
    end
  end
end
