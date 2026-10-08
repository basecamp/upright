require "test_helper"

class Upright::Public::Api::StatusesControllerTest < ActionDispatch::IntegrationTest
  include PublicApiHelper

  test "show reports the overall indicator with a short public cache" do
    get "/api/v2/status.json"

    assert_response :success
    assert_match %r{application/json}, response.content_type
    assert_equal "max-age=15, public", response.headers["Cache-Control"]
    assert_equal({ "indicator" => "none", "description" => "All Systems Operational" }, json["status"])
    assert_equal Upright.configuration.public_status_title, json.dig("page", "name")
  end

  test "show can be read by pages on other origins" do
    get "/api/v2/status.json", headers: { "Origin" => "https://widget.example.com" }

    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "show reflects an active incident" do
    declare_incident title: "Example App is down", impact: "critical"

    get "/api/v2/status.json"

    assert_equal "critical", json.dig("status", "indicator")
  end

  test "show is JSON whatever the Accept header asks for" do
    get "/api/v2/status.json", headers: { "Accept" => "text/html" }

    assert_response :success
    assert_match %r{application/json}, response.content_type
  end

  test "show is a cacheable 404 unless enabled" do
    Upright.configuration.stubs(:public_status_json_enabled).returns(false)

    get "/api/v2/status.json"

    assert_response :not_found
    assert_equal "max-age=15, public", response.headers["Cache-Control"]
  end
end
