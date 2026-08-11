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

  test "rollup_day records a rollup per probe with derived status" do
    day = Date.new(2026, 5, 1)
    reads day, uptime(probe_name: "Web", uptime_fraction: 1.0),
               uptime(probe_name: "API", probe_target: "https://example.com/api", uptime_fraction: 0.85)

    Upright::Rollups::ProbeRollup.rollup_day(day)

    web = Upright::Rollups::ProbeRollup.find_by!(probe_name: "Web", period_start: day.beginning_of_day)
    assert_equal 1.0, web.uptime_fraction
    assert_equal "operational", web.status
    assert_equal "example_app", web.probe_service

    api = Upright::Rollups::ProbeRollup.find_by!(probe_name: "API", period_start: day.beginning_of_day)
    assert_equal 0.85, api.uptime_fraction
    assert_equal "partial_outage", api.status
  end

  test "rollup_day keeps probes that share a name but differ by type as distinct rows" do
    day = Date.new(2026, 5, 1)
    reads day, uptime(probe_name: "BC3", probe_type: "traceroute", probe_target: "3.basecamp.com", probe_service: nil, uptime_fraction: 1.0),
               uptime(probe_name: "BC3", probe_type: "http", probe_target: "https://app.basecamp.com/up", probe_service: "bc5", uptime_fraction: 0.9)

    Upright::Rollups::ProbeRollup.rollup_day(day)

    rollups = Upright::Rollups::ProbeRollup.where(probe_name: "BC3", period_start: day.beginning_of_day)
    assert_equal 2, rollups.count
    assert_equal 0.9, rollups.find_by(probe_type: "http").uptime_fraction
    assert_nil rollups.find_by(probe_type: "traceroute").probe_service
  end

  test "rollup_day corrects an existing rollup rather than leaving it wrong forever" do
    existing = upright_rollups_probe_rollups(:example_web_may_11)
    reads existing.period_start.to_date, uptime(
      probe_name: existing.probe_name, probe_type: existing.probe_type,
      probe_target: existing.probe_target, probe_service: existing.probe_service, uptime_fraction: 1.0
    )

    Upright::Rollups::ProbeRollup.rollup_day(existing.period_start.to_date)

    assert_equal 1.0, existing.reload.uptime_fraction
    assert_equal "operational", existing.status
  end

  test "rollup_day leaves a thinly covered probe unwritten and reports it" do
    day = Date.new(2026, 5, 1)
    reads day, uptime(probe_name: "Thin", coverage_fraction: 0.2),
               uptime(probe_name: "Full", probe_target: "https://example.com/ok", uptime_fraction: 0.9)

    gappy = Upright::Rollups::ProbeRollup.rollup_day(day)

    assert_equal [ "Thin" ], gappy.map(&:probe_name)
    assert_nil Upright::Rollups::ProbeRollup.find_by(probe_name: "Thin", period_start: day.beginning_of_day)
    assert Upright::Rollups::ProbeRollup.find_by(probe_name: "Full", period_start: day.beginning_of_day)
  end

  test "rollup_day won't let a thin recompute overwrite a day it already got right" do
    existing = upright_rollups_probe_rollups(:example_web_may_11)
    reads existing.period_start.to_date, uptime(
      probe_name: existing.probe_name, probe_type: existing.probe_type,
      probe_target: existing.probe_target, probe_service: existing.probe_service,
      uptime_fraction: 1.0, coverage_fraction: 0.1
    )

    Upright::Rollups::ProbeRollup.rollup_day(existing.period_start.to_date)

    assert_equal 0.95, existing.reload.uptime_fraction
  end

  private
    def uptime(probe_name:, probe_type: "http", probe_target: "https://example.com", probe_service: "example_app", uptime_fraction: 1.0, coverage_fraction: 1.0)
      Upright::Rollups::ProbeUptime.new(
        probe_name: probe_name, probe_type: probe_type, probe_target: probe_target,
        probe_service: probe_service, uptime_fraction: uptime_fraction, coverage_fraction: coverage_fraction
      )
    end

    def reads(day, *probe_uptimes)
      daily = stub(covered: probe_uptimes.select(&:covered?), gappy: probe_uptimes.reject(&:covered?))
      Upright::Rollups::DailyUptime.stubs(:new).with(day).returns(daily)
    end
end
