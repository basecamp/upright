require "test_helper"

class Upright::Rollups::DailyUptimeTest < ActiveSupport::TestCase
  setup { @day = Date.new(2026, 5, 1) }

  test "takes each probe from the site that covered the day best" do
    outage_survivor = site_reporting(uptime(probe_name: "Web", uptime_fraction: 0.82, coverage_fraction: 1.0))
    was_itself_down = site_reporting(uptime(probe_name: "Web", uptime_fraction: 1.0, coverage_fraction: 0.1))

    daily = Upright::Rollups::DailyUptime.new(@day, sites: [ was_itself_down, outage_survivor ])

    assert_equal [ 0.82 ], daily.covered.map(&:uptime_fraction)
    assert_empty daily.gappy
  end

  test "keeps distinct probes apart while coalescing" do
    site = site_reporting(
      uptime(probe_name: "Web", uptime_fraction: 1.0),
      uptime(probe_name: "API", probe_target: "https://example.com/api", uptime_fraction: 0.9)
    )

    assert_equal %w[ Web API ].sort, Upright::Rollups::DailyUptime.new(@day, sites: [ site ]).covered.map(&:probe_name).sort
  end

  test "separates probes covered well enough to write from the rest" do
    site = site_reporting(
      uptime(probe_name: "Full", coverage_fraction: 0.95),
      uptime(probe_name: "Thin", probe_target: "https://example.com/thin", coverage_fraction: 0.3)
    )

    daily = Upright::Rollups::DailyUptime.new(@day, sites: [ site ])

    assert_equal [ "Full" ], daily.covered.map(&:probe_name)
    assert_equal [ "Thin" ], daily.gappy.map(&:probe_name)
  end

  test "asks only the sites that keep metrics" do
    Upright.stubs(:sites).returns([ Upright::Site.new(code: "nyc", city: "New York City"), stores_metrics_site ])

    Upright::Rollups::SiteUptime.expects(:new).with(anything, on: @day).once.returns(stub(probe_uptimes: []))

    Upright::Rollups::DailyUptime.new(@day).covered
  end

  private
    def uptime(probe_name:, probe_type: "http", probe_target: "https://example.com", probe_service: "example_app", uptime_fraction: 1.0, coverage_fraction: 1.0)
      Upright::Rollups::ProbeUptime.new(
        probe_name: probe_name, probe_type: probe_type, probe_target: probe_target,
        probe_service: probe_service, uptime_fraction: uptime_fraction, coverage_fraction: coverage_fraction
      )
    end

    def site_reporting(*probe_uptimes)
      stores_metrics_site.tap do |site|
        Upright::Rollups::SiteUptime.stubs(:new).with(site, on: @day).returns(stub(probe_uptimes: probe_uptimes))
      end
    end

    def stores_metrics_site
      Upright::Site.new(code: "sfo", city: "San Francisco", stores_metrics: true)
    end
end
