require "test_helper"

class Upright::Rollups::DailyAggregationJobTest < ActiveSupport::TestCase
  test "aggregates yesterday and earlier — today is still in progress" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      Upright::Rollups::ProbeRollup.stubs(:rollup_day).returns([])
      Upright::Rollups::ProbeRollup.expects(:rollup_day).with(Date.yesterday).once.returns([])
      Upright::Rollups::ProbeRollup.expects(:rollup_day).with(Date.current).never

      Upright::Rollups::DailyAggregationJob.new.perform
    end
  end

  test "backfills a week, so a day skipped for thin coverage gets another chance" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      (Date.new(2026, 5, 5)..Date.new(2026, 5, 11)).each do |day|
        Upright::Rollups::ProbeRollup.expects(:rollup_day).with(day).once.returns([])
      end

      Upright::Rollups::DailyAggregationJob.new.perform
    end
  end

  test "reports the probes it skipped" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      Upright::Rollups::ProbeRollup.stubs(:rollup_day).returns([ thin_probe, thin_probe ])

      Upright::Rollups::DailyAggregationJob.new.perform

      assert_equal 14, yabeda_gauge_value(:rollup_skipped_probes)
    end
  end

  test "past: 0.days skips aggregation entirely since today is excluded" do
    travel_to Time.zone.local(2026, 5, 12, 14, 0) do
      Upright::Rollups::ProbeRollup.expects(:rollup_day).never

      Upright::Rollups::DailyAggregationJob.new.perform(past: 0.days)
      assert_equal 0, yabeda_gauge_value(:rollup_skipped_probes)
    end
  end

  private
    def thin_probe
      Upright::Rollups::ProbeUptime.new(
        probe_name: "Thin", probe_type: "http", probe_target: "https://example.com",
        probe_service: nil, uptime_fraction: 1.0, coverage_fraction: 0.1
      )
    end
end
