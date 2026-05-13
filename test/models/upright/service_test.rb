require "test_helper"

class Upright::ServiceTest < ActiveSupport::TestCase
  test "loads services from config/services.yml" do
    codes = Upright::Service.all.map(&:code)

    assert_includes codes, "example_app"
    assert_includes codes, "internal_tools"
  end

  test "find_by code returns the matching service" do
    service = Upright::Service.find_by(code: "example_app")

    assert_equal "Example App", service.name
  end

  test "uptime_for takes the worst probe rollup for the day" do
    service = Upright::Service.find_by(code: "example_app")
    day = Date.new(2026, 5, 11)

    Upright::Rollups::ProbeRollup.create!(probe_name: "Web", probe_service: "example_app",
      period_start: day.beginning_of_day, uptime_fraction: 0.85, status: :partial_outage)
    Upright::Rollups::ProbeRollup.create!(probe_name: "API", probe_service: "example_app",
      period_start: day.beginning_of_day, uptime_fraction: 1.0, status: :operational)

    assert_equal 0.85, service.uptime_for(day)
    assert_equal :partial_outage, service.status_for(day)
  end

  test "daily_uptime groups by day across the lookback window" do
    service = Upright::Service.find_by(code: "example_app")

    Upright::Rollups::ProbeRollup.create!(probe_name: "Web", probe_service: "example_app",
      period_start: 2.days.ago.beginning_of_day, uptime_fraction: 0.95, status: :degraded_performance)
    Upright::Rollups::ProbeRollup.create!(probe_name: "Web", probe_service: "example_app",
      period_start: 1.day.ago.beginning_of_day, uptime_fraction: 1.0, status: :operational)
    Upright::Rollups::ProbeRollup.create!(probe_name: "API", probe_service: "example_app",
      period_start: 1.day.ago.beginning_of_day, uptime_fraction: 0.8, status: :partial_outage)

    series = service.daily_uptime(days: 7)

    assert_equal 0.95, series[2.days.ago.beginning_of_day]
    assert_equal 0.8, series[1.day.ago.beginning_of_day]
  end
end
