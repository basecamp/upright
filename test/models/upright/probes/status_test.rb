require "test_helper"

class Upright::Probes::StatusTest < ActiveSupport::TestCase
  test ".for_type returns sorted Probe objects grouped by probe identity" do
    stub_prometheus_query_range([
      { "metric" => { "name" => "beta.example.com", "type" => "http", "probe_target" => "https://beta.example.com", "site_code" => "iad" },
        "values" => [ [ 2.minutes.ago.to_i, "1" ] ] },
      { "metric" => { "name" => "beta.example.com", "type" => "http", "probe_target" => "https://beta.example.com", "site_code" => "ams" },
        "values" => [ [ 2.minutes.ago.to_i, "1" ] ] },
      { "metric" => { "name" => "alpha.example.com", "type" => "http", "probe_target" => "https://alpha.example.com", "site_code" => "iad" },
        "values" => [ [ 2.minutes.ago.to_i, "0" ] ] }
    ])

    probes = Upright::Probes::Status.for_type(:http)

    assert_equal 2, probes.size
    assert_equal "alpha.example.com", probes.first.name
    assert_equal "beta.example.com", probes.last.name
    assert_equal 2, probes.last.site_statuses.size
  end

  test ".for_type returns empty array when no results" do
    stub_prometheus_query_range([])

    assert_equal [], Upright::Probes::Status.for_type(:http)
  end

  test ".for_type scopes the query to the deployment environment" do
    with_rails_env("staging") do
      stub_prometheus_query_range([])

      Upright::Probes::Status.for_type(:http)

      assert_requested :get, /localhost:9090.*query_range/ do |request|
        request.uri.query_values["query"].include?(%(environment="staging"))
      end
    end
  end

  test "probe exposes site statuses with up/down state" do
    stub_prometheus_query_range([
      { "metric" => { "name" => "example.com", "type" => "http", "probe_target" => "https://example.com", "site_code" => "iad" },
        "values" => [ [ 2.minutes.ago.to_i, "1" ] ] },
      { "metric" => { "name" => "example.com", "type" => "http", "probe_target" => "https://example.com", "site_code" => "ams" },
        "values" => [ [ 2.minutes.ago.to_i, "0" ] ] }
    ])

    probes = Upright::Probes::Status.for_type(:http)
    probe = probes.first

    assert probe.any_down?
    assert probe.status_for_site("iad").up?
    assert probe.status_for_site("ams").down?
  end

  private
    def stub_prometheus_query_range(result)
      response = { status: "success", data: { resultType: "matrix", result: result } }

      stub_request(:get, /localhost:9090.*query_range/)
        .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
    end
end
