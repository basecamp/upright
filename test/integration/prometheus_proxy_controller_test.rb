require "test_helper"
require "webmock/minitest"

class PrometheusProxyControllerTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain :app
    ENV["PROMETHEUS_OTLP_TOKEN"] = "test-token"
  end

  test "proxies requests when authenticated" do
    stub_request(:get, "http://localhost:9090/graph").to_return(status: 200, body: "Prometheus UI")
    sign_in

    get "/prometheus/graph"

    assert_response :success
  end

  test "OTLP endpoint accepts valid token" do
    stub_request(:post, "http://localhost:9090/api/v1/otlp/v1/metrics").to_return(status: 200)

    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Authorization" => "Bearer test-token", "Content-Type" => "application/x-protobuf" }

    assert_response :success
  end

  test "proxies at a site that stores metrics" do
    stub_request(:get, "http://localhost:9090/graph").to_return(status: 200, body: "Prometheus UI")
    sign_in
    on_subdomain :ams

    get "/prometheus/graph"

    assert_response :success
  end

  test "accepts OTLP writes at a site that stores metrics" do
    stub_request(:post, "http://localhost:9090/api/v1/otlp/v1/metrics").to_return(status: 200)
    on_subdomain :ams

    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Authorization" => "Bearer test-token", "Content-Type" => "application/x-protobuf" }

    assert_response :success
  end

  test "token stands in for a session, so a peer site can be read" do
    stub_request(:get, "http://localhost:9090/api/v1/query?query=up").to_return(status: 200, body: "{}")
    on_subdomain :ams

    get "/prometheus/api/v1/query?query=up", headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
  end

  test "rejects a bad token instead of redirecting to the login" do
    on_subdomain :ams

    get "/prometheus/api/v1/query?query=up", headers: { "Authorization" => "Bearer wrong-token" }

    assert_response :unauthorized
  end

  test "not routable at a probe-only site" do
    sign_in
    on_subdomain :nyc

    get "/prometheus/graph"

    assert_response :not_found
  end

  test "proxy requires authentication" do
    get "/prometheus/graph"

    assert_response :redirect
    assert response.location.end_with?("/session/new")
  end

  test "OTLP endpoint rejects missing token" do
    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Content-Type" => "application/x-protobuf" }

    assert_response :unauthorized
  end

  test "OTLP endpoint rejects invalid token" do
    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Authorization" => "Bearer wrong-token", "Content-Type" => "application/x-protobuf" }

    assert_response :unauthorized
  end
end
