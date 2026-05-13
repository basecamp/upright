require "test_helper"

class Upright::Rollups::DailyAggregationJobTest < ActiveSupport::TestCase
  test "delegates aggregation per day to the rollup models" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      today = Date.current
      yesterday = today - 1.day

      Upright::Rollups::ProbeRollup.expects(:aggregate_day).with(today).once
      Upright::Rollups::ProbeRollup.expects(:aggregate_day).with(yesterday).once
      Upright::Rollups::ServiceRollup.expects(:aggregate_day).with(today).once
      Upright::Rollups::ServiceRollup.expects(:aggregate_day).with(yesterday).once

      Upright::Rollups::DailyAggregationJob.new.perform
    end
  end

  test "days_back: 0 only aggregates today" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      Upright::Rollups::ProbeRollup.expects(:aggregate_day).with(Date.current).once
      Upright::Rollups::ServiceRollup.expects(:aggregate_day).with(Date.current).once

      Upright::Rollups::DailyAggregationJob.new.perform(days_back: 0)
    end
  end
end
