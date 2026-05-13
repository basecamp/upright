require "test_helper"

class Upright::Rollups::ServiceRollupTest < ActiveSupport::TestCase
  setup do
    Upright::Rollups::ProbeRollup.delete_all
    Upright::Rollups::ServiceRollup.delete_all
  end

  test "aggregate_day takes the worst probe uptime per service" do
    day = Date.new(2026, 5, 11)

    Upright::Rollups::ProbeRollup.create!(probe_name: "Web", probe_service: "example_app",
      period_start: day.beginning_of_day, uptime_fraction: 0.85, status: :partial_outage)
    Upright::Rollups::ProbeRollup.create!(probe_name: "API", probe_service: "example_app",
      period_start: day.beginning_of_day, uptime_fraction: 1.0, status: :operational)

    Upright::Rollups::ServiceRollup.aggregate_day(day)

    service = Upright::Rollups::ServiceRollup.find_by!(service_code: "example_app", period_start: day.beginning_of_day)
    assert_equal 0.85, service.uptime_fraction
    assert_equal "partial_outage", service.status
  end

  test "aggregate_day ignores probe rollups with no service" do
    day = Date.new(2026, 5, 11)

    Upright::Rollups::ProbeRollup.create!(probe_name: "Orphan", probe_service: nil,
      period_start: day.beginning_of_day, uptime_fraction: 0.5, status: :partial_outage)

    Upright::Rollups::ServiceRollup.aggregate_day(day)

    assert_equal 0, Upright::Rollups::ServiceRollup.count
  end
end
