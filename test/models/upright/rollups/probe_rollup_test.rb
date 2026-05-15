require "test_helper"

class Upright::Rollups::ProbeRollupTest < ActiveSupport::TestCase
  test "uptime_percentage scales uptime_fraction to a percentage" do
    rollup = Upright::Rollups::ProbeRollup.new(uptime_fraction: 0.995)
    assert_equal 99.5, rollup.uptime_percentage
  end

  test "uptime_percentage returns nil when uptime_fraction is nil" do
    rollup = Upright::Rollups::ProbeRollup.new(uptime_fraction: nil)
    assert_nil rollup.uptime_percentage
  end

  test "saving derives status from uptime_fraction" do
    rollup = upright_rollups_probe_rollups(:example_web_may_11)
    rollup.update!(uptime_fraction: 0.4)
    assert_equal "major_outage", rollup.status
  end

  test "aggregate_day creates a rollup per probe uptime with derived status" do
    day = Date.new(2026, 5, 1)
    probe_uptimes = [
      { probe_name: "Web", probe_service: "example_app", uptime_fraction: 1.0 },
      { probe_name: "API", probe_service: "example_app", uptime_fraction: 0.85 }
    ]

    Upright::Rollups::ProbeRollup.stubs(:fetch_uptime_for).with(day).returns(probe_uptimes)
    Upright::Rollups::ProbeRollup.aggregate_day(day)

    web = Upright::Rollups::ProbeRollup.find_by!(probe_name: "Web", period_start: day.beginning_of_day)
    assert_equal 1.0, web.uptime_fraction
    assert_equal "operational", web.status
    assert_equal "example_app", web.probe_service

    api = Upright::Rollups::ProbeRollup.find_by!(probe_name: "API", period_start: day.beginning_of_day)
    assert_equal 0.85, api.uptime_fraction
    assert_equal "partial_outage", api.status
  end

  test "aggregate_day leaves existing rollups unchanged" do
    existing = upright_rollups_probe_rollups(:example_web_may_11)

    Upright::Rollups::ProbeRollup.stubs(:fetch_uptime_for).with(existing.period_start.to_date).returns([
      { probe_name: existing.probe_name, probe_service: existing.probe_service, uptime_fraction: 1.0 }
    ])
    Upright::Rollups::ProbeRollup.aggregate_day(existing.period_start.to_date)

    existing.reload
    assert_equal 0.95, existing.uptime_fraction
    assert_equal "degraded", existing.status
  end
end
