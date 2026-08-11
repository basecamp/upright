require "test_helper"

class Upright::Rollups::SiteUptimeTest < ActiveSupport::TestCase
  setup { @day = Date.new(2026, 5, 1) }

  test "reads a probe's uptime and how much of the day it covers" do
    probe_uptime = uptimes_from(site_answering(uptime: 0.82, samples: 2_880)).sole

    assert_equal "Web", probe_uptime.probe_name
    assert_equal "http", probe_uptime.probe_type
    assert_equal "https://example.com", probe_uptime.probe_target
    assert_equal "example_app", probe_uptime.probe_service
    assert_equal 0.82, probe_uptime.uptime_fraction
    assert_equal 1.0, probe_uptime.coverage_fraction
  end

  test "counts coverage against the recording interval" do
    assert_in_delta 0.5, uptimes_from(site_answering(uptime: 0.9, samples: 1_440)).sole.coverage_fraction
  end

  test "caps coverage at whole, since a window can hold more samples than expected" do
    assert_equal 1.0, uptimes_from(site_answering(uptime: 0.9, samples: 5_000)).sole.coverage_fraction
  end

  test "treats a probe missing from the coverage query as uncovered" do
    client = mock("prometheus_client")
    client.stubs(:query).with(has_entries(query: uptime_query)).returns(vector(0.9))
    client.stubs(:query).with(has_entries(query: coverage_query)).returns({ "result" => [] })

    assert_equal 0.0, uptimes_from(site_with(client)).sole.coverage_fraction
  end

  test "contributes nothing when the site can't be reached" do
    client = mock("prometheus_client")
    client.stubs(:query).raises(Faraday::ConnectionFailed, "down")

    assert_empty uptimes_from(site_with(client))
  end

  test "counts coverage from the series that stops during a gap, not the daily average that carries on through one" do
    asked = []
    client = mock("prometheus_client")
    client.stubs(:query).with { |options| asked << options[:query]; true }.returns(vector(1.0))

    uptimes_from(site_with(client))

    assert_includes asked, %(upright:probe_uptime_daily{environment="test"})
    assert_includes asked, %(count_over_time(upright:probe_down_fraction{environment="test"}[1d]))
  end

  test "asks about a past day at the end of that day" do
    client = mock("prometheus_client")
    client.expects(:query).with(has_entries(time: @day.end_of_day.iso8601)).twice.returns(vector(1.0))

    uptimes_from(site_with(client))
  end

  test "asks about today only up to now" do
    travel_to Time.zone.local(2026, 5, 12, 9, 30) do
      client = mock("prometheus_client")
      client.expects(:query).with(has_entries(time: Time.current.iso8601)).twice.returns(vector(1.0))

      Upright::Rollups::SiteUptime.new(site_with(client), on: Date.current).probe_uptimes
    end
  end

  private
    def uptimes_from(site)
      Upright::Rollups::SiteUptime.new(site, on: @day).probe_uptimes
    end

    def site_answering(uptime:, samples:)
      client = mock("prometheus_client")
      client.stubs(:query).with(has_entries(query: uptime_query)).returns(vector(uptime))
      client.stubs(:query).with(has_entries(query: coverage_query)).returns(vector(samples))
      site_with(client)
    end

    def site_with(client)
      Upright::Site.new(code: "sfo", city: "San Francisco", stores_metrics: true).tap do |site|
        site.stubs(:prometheus_client).returns(client)
      end
    end

    def uptime_query
      %(upright:probe_uptime_daily{environment="test"})
    end

    def coverage_query
      %(count_over_time(upright:probe_down_fraction{environment="test"}[1d]))
    end

    def vector(value)
      {
        "resultType" => "vector",
        "result" => [
          {
            "metric" => { "name" => "Web", "type" => "http", "probe_target" => "https://example.com", "probe_service" => "example_app" },
            "value" => [ 1_777_000_000, value.to_s ]
          }
        ]
      }
    end
end
