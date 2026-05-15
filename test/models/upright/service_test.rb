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

  test "public_facing returns only services flagged public" do
    codes = Upright::Service.public_facing.map(&:code)

    assert_includes codes, "example_app"
    assert_not_includes codes, "internal_tools"
  end

  test "uptime_for takes the worst probe rollup for the day" do
    service = Upright::Service.find_by(code: "example_app")
    day = Date.new(2026, 5, 5)

    assert_equal 0.85, service.uptime_for(day)
  end

  test "daily_uptime groups by day across the lookback window" do
    travel_to Date.new(2026, 5, 13) do
      service = Upright::Service.find_by(code: "example_app")
      series = service.daily_uptime(past: 7.days)

      assert_equal 0.95, series[Date.new(2026, 5, 11).beginning_of_day]
      assert_equal 0.8,  series[Date.new(2026, 5, 12).beginning_of_day]
    end
  end
end
