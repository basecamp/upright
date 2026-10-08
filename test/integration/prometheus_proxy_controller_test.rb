require "test_helper"
require "webmock/minitest"

class PrometheusProxyControllerTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain :app
    ENV["PROMETHEUS_OTLP_TOKEN"] = "otlp-token"
    ENV["METRICS_READ_TOKEN"] = "read-token"
  end

  test "the framed page is served to a session arriving from another subdomain" do
    # The header links here from the app subdomain, which the browser reports
    # as same-site. The page only frames the UI, so the proxy gate does not
    # apply to it.
    sign_in
    on_subdomain :ams

    get "/framed/prometheus", headers: { "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "navigate" }

    assert_response :success
    assert_select "iframe.service-frame"
  end

  test "the framed page still requires a session" do
    on_subdomain :ams

    get "/framed/prometheus", headers: { "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "navigate" }

    assert_response :redirect
    assert response.location.end_with?("/session/new")
  end

  test "the proxy itself is still refused for a same-site request" do
    stub = stub_request(:get, "http://localhost:9090/graph")
    sign_in
    on_subdomain :ams

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "navigate" }

    assert_response :forbidden
    assert_not_requested stub
  end

  test "serves the upstream UI's script bundle to a same-origin script tag" do
    # A <script src> request is a GET that is not an XHR. Rails' forgery
    # protection refuses JavaScript to those unless the action opts out.
    stub_request(:get, "http://localhost:9090/assets/index.js")
      .to_return(status: 200, body: "console.log(1)", headers: { "Content-Type" => "text/javascript; charset=utf-8" })
    sign_in

    with_forgery_protection do
      get "/prometheus/assets/index.js", headers: { "Sec-Fetch-Site" => "same-origin", "Sec-Fetch-Mode" => "cors", "Sec-Fetch-Dest" => "script" }
    end

    assert_response :success
    assert_equal "console.log(1)", response.body
  end

  test "a cross-site script tag is still refused" do
    stub = stub_request(:get, "http://localhost:9090/assets/index.js")
    sign_in

    with_forgery_protection do
      get "/prometheus/assets/index.js", headers: { "Sec-Fetch-Site" => "cross-site", "Sec-Fetch-Mode" => "no-cors", "Sec-Fetch-Dest" => "script" }
    end

    assert_response :forbidden
    assert_not_requested stub
  end

  test "proxies requests when authenticated" do
    stub_request(:get, "http://localhost:9090/graph").to_return(status: 200, body: "Prometheus UI")
    sign_in

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
  end

  test "OTLP endpoint accepts the OTLP token" do
    stub_request(:post, "http://localhost:9090/api/v1/otlp/v1/metrics").to_return(status: 200)

    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Authorization" => "Bearer otlp-token", "Content-Type" => "application/x-protobuf" }

    assert_response :success
  end

  test "OTLP endpoint responds service unavailable when Prometheus cannot be reached" do
    stub_request(:post, "http://localhost:9090/api/v1/otlp/v1/metrics").to_raise(Faraday::ConnectionFailed.new("connection refused"))

    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Authorization" => "Bearer otlp-token", "Content-Type" => "application/x-protobuf" }

    assert_response :service_unavailable
  end

  test "proxy responds service unavailable when Prometheus times out" do
    stub_request(:get, "http://localhost:9090/graph").to_timeout
    sign_in

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :service_unavailable
  end

  test "proxies at a site that stores metrics" do
    stub_request(:get, "http://localhost:9090/graph").to_return(status: 200, body: "Prometheus UI")
    sign_in
    on_subdomain :ams

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
  end

  test "accepts OTLP writes at a site that stores metrics" do
    stub_request(:post, "http://localhost:9090/api/v1/otlp/v1/metrics").to_return(status: 200)
    on_subdomain :ams

    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Authorization" => "Bearer otlp-token", "Content-Type" => "application/x-protobuf" }

    assert_response :success
  end

  test "the read token stands in for a session, so a peer site can be read" do
    stub_request(:get, "http://localhost:9090/api/v1/query?query=up").to_return(status: 200, body: "{}")
    on_subdomain :ams

    get "/prometheus/api/v1/query?query=up", headers: { "Authorization" => "Bearer read-token" }

    assert_response :success
  end

  test "the OTLP token cannot read" do
    stub = stub_request(:get, "http://localhost:9090/api/v1/query?query=up")
    on_subdomain :ams

    get "/prometheus/api/v1/query?query=up", headers: { "Authorization" => "Bearer otlp-token" }

    assert_response :unauthorized
    assert_not_requested stub
  end

  test "the read token cannot write metrics" do
    stub = stub_request(:post, "http://localhost:9090/api/v1/otlp/v1/metrics")
    on_subdomain :ams

    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Authorization" => "Bearer read-token", "Content-Type" => "application/x-protobuf" }

    assert_response :unauthorized
    assert_not_requested stub
  end

  test "a blank configured token matches nothing" do
    stub = stub_request(:get, "http://localhost:9090/api/v1/query?query=up")
    on_subdomain :ams

    with_env("METRICS_READ_TOKEN" => nil) do
      get "/prometheus/api/v1/query?query=up", headers: { "Authorization" => "Bearer read-token" }
    end

    assert_response :unauthorized
    assert_not_requested stub
  end

  test "rejects a bad token instead of redirecting to the login" do
    on_subdomain :ams

    get "/prometheus/api/v1/query?query=up", headers: { "Authorization" => "Bearer wrong-token" }

    assert_response :unauthorized
  end

  test "not routable at a probe-only site" do
    sign_in
    on_subdomain :nyc

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :not_found
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
