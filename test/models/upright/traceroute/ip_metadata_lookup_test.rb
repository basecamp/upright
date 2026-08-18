require "test_helper"

class Upright::Traceroute::IpMetadataLookupTest < ActiveSupport::TestCase
  setup do
    Upright::Traceroute::IpMetadataLookup.clear_cache
  end

  test "looks up multiple IPs in single batch request" do
    stub = stub_ip_api_request(
      request_ips: [ "8.8.8.8", "1.1.1.1" ],
      response: [
        { "query" => "8.8.8.8", "status" => "success", "as" => "AS15169 Google LLC", "isp" => "Google LLC", "city" => "Mountain View", "country" => "United States", "countryCode" => "US", "lat" => 37.386, "lon" => -122.0838 },
        { "query" => "1.1.1.1", "status" => "success", "as" => "AS13335 Cloudflare", "isp" => "Cloudflare", "city" => "Sydney", "country" => "Australia", "countryCode" => "AU", "lat" => -33.8688, "lon" => 151.2093 }
      ]
    )

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8", "1.1.1.1" ])

    assert_equal "AS15169 Google LLC", results["8.8.8.8"][:as]
    assert_equal "Google LLC", results["8.8.8.8"][:isp]
    assert_equal "Mountain View", results["8.8.8.8"][:city]
    assert_equal "9q9htv", results["8.8.8.8"][:geohash]
    assert_equal "AS13335 Cloudflare", results["1.1.1.1"][:as]
    assert_equal "Cloudflare", results["1.1.1.1"][:isp]
    assert_requested stub, times: 1
  end

  test "caches results and only fetches uncached IPs" do
    stub_ip_api_request(
      request_ips: [ "8.8.8.8" ],
      response: [ { "query" => "8.8.8.8", "status" => "success", "as" => "AS15169", "isp" => "Google LLC" } ]
    )

    Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8" ])

    stub = stub_ip_api_request(
      request_ips: [ "1.1.1.1" ],
      response: [ { "query" => "1.1.1.1", "status" => "success", "as" => "AS13335", "isp" => "Cloudflare" } ]
    )

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8", "1.1.1.1" ])

    assert_equal "AS15169", results["8.8.8.8"][:as]
    assert_equal "AS13335", results["1.1.1.1"][:as]
    assert_requested stub, times: 1
  end

  test "returns empty hash for empty input" do
    results = Upright::Traceroute::IpMetadataLookup.for_many([])
    assert_equal({}, results)
  end

  test "filters out invalid IPs" do
    stub = stub_ip_api_request(
      request_ips: [ "8.8.8.8" ],
      response: [ { "query" => "8.8.8.8", "status" => "success", "as" => "AS15169" } ]
    )

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8", "???", "hostname.com", nil ])

    assert_equal 1, results.size
    assert_equal "AS15169", results["8.8.8.8"][:as]
  end

  test "skips API call when all IPs are cached" do
    stub_ip_api_request(response: [
      { "query" => "8.8.8.8", "status" => "success", "as" => "AS15169" },
      { "query" => "1.1.1.1", "status" => "success", "as" => "AS13335" }
    ])

    Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8", "1.1.1.1" ])

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8", "1.1.1.1" ])

    assert_equal "AS15169", results["8.8.8.8"][:as]
    assert_equal "AS13335", results["1.1.1.1"][:as]
    assert_requested :post, "http://ip-api.com/batch", times: 1
  end

  test "handles failed lookups in batch response" do
    stub_ip_api_request(response: [
      { "query" => "8.8.8.8", "status" => "success", "as" => "AS15169" },
      { "query" => "192.168.1.1", "status" => "fail", "message" => "private range" }
    ])

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8", "192.168.1.1" ])

    assert_equal "AS15169", results["8.8.8.8"][:as]
    assert_nil results["192.168.1.1"]
  end

  test "returns empty hash on API error" do
    stub_ip_api_request(status: 429, body: "Too Many Requests")

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8" ])

    assert_equal({}, results)
  end

  test "deduplicates IPs" do
    stub = stub_ip_api_request(
      request_ips: [ "8.8.8.8" ],
      response: [ { "query" => "8.8.8.8", "status" => "success", "as" => "AS15169" } ]
    )

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8", "8.8.8.8", "8.8.8.8" ])

    assert_equal 1, results.size
    assert_requested stub, times: 1
  end

  test "uses the TLS pro endpoint when an API key is configured" do
    Upright::Traceroute::IpMetadataLookup.stubs(:api_key).returns("test-key")
    stub = stub_request(:post, "https://pro.ip-api.com/batch?key=test-key")
      .to_return(status: 200, body: [ { "query" => "8.8.8.8", "status" => "success", "as" => "AS15169" } ].to_json)

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8" ])

    assert_equal "AS15169", results["8.8.8.8"][:as]
    assert_requested stub, times: 1
  end

  test "handles missing as field" do
    stub_ip_api_request(response: [ { "query" => "8.8.8.8", "status" => "success", "isp" => "Google LLC" } ])

    results = Upright::Traceroute::IpMetadataLookup.for_many([ "8.8.8.8" ])

    assert_nil results["8.8.8.8"][:as]
    assert_equal "Google LLC", results["8.8.8.8"][:isp]
  end

  private
    def stub_ip_api_request(request_ips: nil, response: nil, status: 200, body: nil)
      stub = stub_request(:post, "http://ip-api.com/batch")
      stub = stub.with(body: request_ips.to_json) if request_ips
      stub.to_return(status: status, body: body || response.to_json)
    end
end
