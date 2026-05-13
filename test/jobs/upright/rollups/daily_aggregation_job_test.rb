require "test_helper"

class Upright::Rollups::DailyAggregationJobTest < ActiveSupport::TestCase
  test "aggregates today and the lookback window into ProbeRollup" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      today = Date.today
      yesterday = today - 1.day

      Upright::Rollups::ProbeRollup.expects(:aggregate_day).with(yesterday).once
      Upright::Rollups::ProbeRollup.expects(:aggregate_day).with(today).once

      Upright::Rollups::DailyAggregationJob.new.perform
    end
  end

  test "lookback: 0.days only aggregates today" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      Upright::Rollups::ProbeRollup.expects(:aggregate_day).with(Date.today).once

      Upright::Rollups::DailyAggregationJob.new.perform(lookback: 0.days)
    end
  end
end
