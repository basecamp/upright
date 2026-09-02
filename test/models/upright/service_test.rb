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

  test "uptime_probe_types defaults to HTTP and reads extra types from services.yml" do
    assert_equal %w[ http ], Upright::Service.find_by(code: "example_app").uptime_probe_types
    assert_equal %w[ http playwright ], Upright::Service.find_by(code: "internal_tools").uptime_probe_types
  end

  test "uptime_probe_types rejects a type that isn't registered" do
    service = Upright::Service.new(code: "typo", name: "Typo", uptime_probe_types: [ "http", "playwrite" ])

    error = assert_raises(Upright::ConfigurationError) { service.uptime_probe_types }
    assert_match(/typo: uptime_probe_types playwrite not registered/, error.message)
  end

  test "daily_uptime only counts the service's uptime probe types" do
    travel_to Date.new(2026, 5, 13) do
      may_10 = Date.new(2026, 5, 10).beginning_of_day

      assert_nil Upright::Service.find_by(code: "example_app").daily_uptime(past: 7.days)[may_10]
      assert_equal 0.5, Upright::Service.find_by(code: "internal_tools").daily_uptime(past: 7.days)[may_10]
    end
  end

  test "daily_uptime keeps counting rollups recorded before probe_type existed" do
    travel_to Date.new(2026, 5, 13) do
      assert_equal 0.7, Upright::Service.find_by(code: "example_app").daily_uptime(past: 7.days)[Date.new(2026, 5, 9).beginning_of_day]
    end
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
