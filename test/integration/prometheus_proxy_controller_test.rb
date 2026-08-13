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

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
  end

  test "OTLP endpoint accepts valid token" do
    stub_request(:post, "http://localhost:9090/api/v1/otlp/v1/metrics").to_return(status: 200)

    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Authorization" => "Bearer test-token", "Content-Type" => "application/x-protobuf" }

    assert_response :success
  end

  test "proxy requires authentication" do
    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-origin" }

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
