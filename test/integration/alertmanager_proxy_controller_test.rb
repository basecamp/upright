require "test_helper"
require "webmock/minitest"

class AlertmanagerProxyControllerTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain :app
  end

  test "the framed page is served to a session arriving from another subdomain" do
    # The header links here from the app subdomain, which the browser reports
    # as same-site. The page only frames the UI, so the proxy gate does not
    # apply to it.
    sign_in
    on_subdomain :ams

    get "/framed/alertmanager", headers: { "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "navigate" }

    assert_response :success
    assert_select "iframe.service-frame"
  end

  test "the framed page still requires a session" do
    on_subdomain :ams

    get "/framed/alertmanager", headers: { "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "navigate" }

    assert_response :redirect
    assert response.location.end_with?("/session/new")
  end

  test "the proxy itself is still refused for a same-site request" do
    stub = stub_request(:get, "http://localhost:9093/")
    sign_in
    on_subdomain :ams

    get "/alertmanager", headers: { "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "navigate" }

    assert_response :forbidden
    assert_not_requested stub
  end

  test "proxies requests when authenticated" do
    stub_request(:get, "http://localhost:9093/")
      .to_return(status: 200, body: "Alertmanager UI")

    sign_in
    get "/alertmanager", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
  end

  test "proxies at a site that stores metrics" do
    stub_request(:get, "http://localhost:9093/api/v2/status").to_return(status: 200, body: "{}")
    sign_in
    on_subdomain :ams

    get "/alertmanager/api/v2/status", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
  end

  test "the read token stands in for a session" do
    stub_request(:get, "http://localhost:9093/api/v2/status").to_return(status: 200, body: "{}")
    on_subdomain :ams

    with_env("METRICS_READ_TOKEN" => "read-token") do
      get "/alertmanager/api/v2/status", headers: { "Authorization" => "Bearer read-token" }
    end

    assert_response :success
  end

  test "the OTLP token cannot read" do
    stub = stub_request(:get, "http://localhost:9093/api/v2/status")
    on_subdomain :ams

    with_env("PROMETHEUS_OTLP_TOKEN" => "otlp-token", "METRICS_READ_TOKEN" => "read-token") do
      get "/alertmanager/api/v2/status", headers: { "Authorization" => "Bearer otlp-token" }
    end

    assert_response :unauthorized
    assert_not_requested stub
  end

  test "not routable at a probe-only site" do
    sign_in
    on_subdomain :nyc

    get "/alertmanager", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :not_found
  end

  test "proxies POST body to alertmanager" do
    silence_json = { matchers: [ { name: "alertname", value: "TestAlert", isRegex: false, isEqual: true } ], comment: "test" }.to_json

    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
      .with(body: silence_json)
      .to_return(status: 200, body: '{"silenceID":"abc-123"}', headers: { "Content-Type" => "application/json" })

    sign_in
    post "/alertmanager/api/v2/silences", params: silence_json,
      headers: { "Content-Type" => "application/json", "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
    assert_requested stub
  end
end
