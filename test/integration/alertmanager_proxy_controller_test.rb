require "test_helper"
require "webmock/minitest"

class AlertmanagerProxyControllerTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain :app
  end

  test "proxies requests when authenticated" do
    stub_request(:get, "http://localhost:9093/")
      .to_return(status: 200, body: "Alertmanager UI")

    sign_in
    get "/alertmanager"

    assert_response :success
  end

  test "proxies at a site that stores metrics" do
    stub_request(:get, "http://localhost:9093/api/v2/status").to_return(status: 200, body: "{}")
    sign_in
    on_subdomain :ams

    get "/alertmanager/api/v2/status"

    assert_response :success
  end

  test "token stands in for a session" do
    stub_request(:get, "http://localhost:9093/api/v2/status").to_return(status: 200, body: "{}")
    on_subdomain :ams

    with_env("PROMETHEUS_OTLP_TOKEN" => "test-token") do
      get "/alertmanager/api/v2/status", headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :success
  end

  test "not routable at a probe-only site" do
    sign_in
    on_subdomain :nyc

    get "/alertmanager"

    assert_response :not_found
  end

  test "proxies POST body to alertmanager" do
    silence_json = { matchers: [ { name: "alertname", value: "TestAlert", isRegex: false, isEqual: true } ], comment: "test" }.to_json

    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
      .with(body: silence_json)
      .to_return(status: 200, body: '{"silenceID":"abc-123"}', headers: { "Content-Type" => "application/json" })

    sign_in
    post "/alertmanager/api/v2/silences", params: silence_json, headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_requested stub
  end
end
