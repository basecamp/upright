require "test_helper"

class Upright::Rollups::ProbeUptimeTest < ActiveSupport::TestCase
  test "counts as covered at or above the configured minimum" do
    assert probe_uptime(coverage_fraction: 0.9).covered?
    assert probe_uptime(coverage_fraction: 0.91).covered?
    assert_not probe_uptime(coverage_fraction: 0.89).covered?
  end

  test "honours a host's own minimum" do
    Upright.configuration.rollup_minimum_coverage = 0.5

    assert probe_uptime(coverage_fraction: 0.6).covered?
  ensure
    Upright.configuration.rollup_minimum_coverage = nil
  end

  test "identifies a probe by name, type and target, as the rollups do" do
    assert_equal [ "Web", "http", "https://example.com" ], probe_uptime.probe_key
  end

  private
    def probe_uptime(coverage_fraction: 1.0)
      Upright::Rollups::ProbeUptime.new(
        probe_name: "Web", probe_type: "http", probe_target: "https://example.com",
        probe_service: "example_app", uptime_fraction: 1.0, coverage_fraction: coverage_fraction
      )
    end
end
