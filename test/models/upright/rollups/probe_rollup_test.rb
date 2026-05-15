require "test_helper"

class Upright::Rollups::ProbeRollupTest < ActiveSupport::TestCase
  setup do
    Upright::Rollups::ProbeRollup.delete_all
  end

  test "uptime_percentage scales uptime_fraction to a percentage" do
    rollup = Upright::Rollups::ProbeRollup.new(uptime_fraction: 0.995)
    assert_equal 99.5, rollup.uptime_percentage
  end

  test "uptime_percentage returns nil when uptime_fraction is nil" do
    rollup = Upright::Rollups::ProbeRollup.new(uptime_fraction: nil)
    assert_nil rollup.uptime_percentage
  end

  test "status_for returns operational when fully up or nil" do
    assert_equal :operational, Upright::Rollups::ProbeRollup.status_for(1.0)
    assert_equal :operational, Upright::Rollups::ProbeRollup.status_for(nil)
  end

  test "status_for returns degraded for minor failures" do
    assert_equal :degraded, Upright::Rollups::ProbeRollup.status_for(0.99)
  end

  test "status_for returns partial_outage for moderate failures" do
    assert_equal :partial_outage, Upright::Rollups::ProbeRollup.status_for(0.8)
  end

  test "status_for returns major_outage when below half" do
    assert_equal :major_outage, Upright::Rollups::ProbeRollup.status_for(0.4)
  end

  test "upsert_day writes uptime_fraction and derived status" do
    day = Date.new(2026, 5, 11)

    Upright::Rollups::ProbeRollup.upsert_day(
      day:, probe_name: "Web", probe_service: "example_app", uptime_fraction: 0.97
    )

    rollup = Upright::Rollups::ProbeRollup.find_by!(probe_name: "Web", period_start: day.beginning_of_day)
    assert_equal 0.97, rollup.uptime_fraction
    assert_equal "degraded", rollup.status
    assert_equal "example_app", rollup.probe_service
  end

  test "aggregate_day pulls uptime samples from Prometheus and upserts" do
    day = Date.new(2026, 5, 11)
    samples = [
      { name: "Web", probe_service: "example_app", uptime_fraction: 1.0 },
      { name: "API", probe_service: "example_app", uptime_fraction: 0.85 }
    ]

    Upright::Rollups::ProbeRollup.stubs(:fetch_uptime_for).with(day).returns(samples)

    Upright::Rollups::ProbeRollup.aggregate_day(day)

    assert_equal "operational", Upright::Rollups::ProbeRollup.find_by!(probe_name: "Web", period_start: day.beginning_of_day).status
    assert_equal "partial_outage", Upright::Rollups::ProbeRollup.find_by!(probe_name: "API", period_start: day.beginning_of_day).status
  end
end
