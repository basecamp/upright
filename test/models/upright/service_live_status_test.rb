require "test_helper"

class Upright::ServiceLiveStatusTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "live_status reuses a cached Prometheus reading within the public cache window" do
    client = mock("prometheus")
    client.expects(:query).once.returns({ "result" => [ { "value" => [ 1765000000, "1" ] } ] })
    Upright.stubs(:prometheus_client).returns(client)

    service = Upright::Service.find_by(code: "example_app")

    assert_equal :major_outage, service.live_status
    assert_equal :major_outage, service.live_status
  end

  test "live_status is cached per service" do
    client = mock("prometheus")
    client.expects(:query).twice.returns({ "result" => [ { "value" => [ 1765000000, "0" ] } ] })
    Upright.stubs(:prometheus_client).returns(client)

    assert_equal :operational, Upright::Service.find_by(code: "example_app").live_status
    assert_equal :operational, Upright::Service.find_by(code: "internal_tools").live_status
  end

  test "live_status asks Prometheus about HTTP probes only by default" do
    client = mock("prometheus")
    client.expects(:query).with { |query:| query.include?(%(type=~"http")) && query.exclude?("playwright") }.returns({ "result" => [] })
    Upright.stubs(:prometheus_client).returns(client)

    assert_equal :operational, Upright::Service.find_by(code: "example_app").live_status
  end

  test "live_status asks about the service's extra uptime_probe_types" do
    client = mock("prometheus")
    client.expects(:query).with { |query:| query.include?(%(type=~"http|playwright")) }.returns({ "result" => [ { "value" => [ 1765000000, "1" ] } ] })
    Upright.stubs(:prometheus_client).returns(client)

    assert_equal :major_outage, Upright::Service.find_by(code: "internal_tools").live_status
  end

  test "live_status escapes probe types for the PromQL regex and string" do
    Upright.configuration.probe_types.register "api.v2", name: "API v2", icon: "🔌"
    service = Upright::Service.new(code: "escaped", name: "Escaped", uptime_probe_types: [ "api.v2" ])

    client = mock("prometheus")
    client.expects(:query).with { |query:| query.include?(%(type=~"api\\\\.v2")) }.returns({ "result" => [] })
    Upright.stubs(:prometheus_client).returns(client)

    assert_equal :operational, service.live_status
  ensure
    Upright.configuration.probe_types.unregister "api.v2"
  end

  test "current_outage_started_at reuses a cached Prometheus range within the public cache window" do
    client = mock("prometheus")
    client.expects(:query_range).once.returns({ "result" => [ { "values" => [ [ 1765000000, "0" ], [ 1765000300, "1" ] ] } ] })
    Upright.stubs(:prometheus_client).returns(client)

    service = Upright::Service.find_by(code: "example_app")

    assert_equal Time.zone.at(1765000300), service.current_outage_started_at
    assert_equal Time.zone.at(1765000300), service.current_outage_started_at
  end
end
