require "test_helper"
require "webmock/minitest"

# Regression coverage for CVE-2026-67990 (proxy CSRF). A browser request on the
# session-cookie path must be refused when it originates cross-site, so a forged
# request can't ride the victim's Lax session cookie into upstream write/admin
# APIs. Genuine same-origin calls from the embedded UI still forward, and the
# token-authenticated OTLP endpoint stays on its own 401 path.
class ProxyCsrfTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain :app
    ENV["PROMETHEUS_OTLP_TOKEN"] = "test-token"
  end

  # --- The forged cross-site vectors are refused, POST and the Lax-cookie GET ---

  test "cross-site POST to alertmanager on the session path is forbidden" do
    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
    sign_in

    post "/alertmanager/api/v2/silences",
      params: { comment: "forged" }.to_json,
      headers: { "Content-Type" => "application/json", "Sec-Fetch-Site" => "cross-site" }

    assert_response :forbidden
    assert_not_requested stub
  end

  test "cross-site GET to prometheus on the session path is forbidden" do
    stub = stub_request(:get, "http://localhost:9090/-/reload")
    sign_in

    # Top-level Lax-cookie navigation vector: a cross-site GET carries no Origin
    # header, only Sec-Fetch-Site.
    get "/prometheus/-/reload", headers: { "Sec-Fetch-Site" => "cross-site" }

    assert_response :forbidden
    assert_not_requested stub
  end

  test "foreign Origin on the session path is forbidden when Sec-Fetch is absent" do
    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
    sign_in

    post "/alertmanager/api/v2/silences",
      params: { comment: "forged" }.to_json,
      headers: { "Content-Type" => "application/json", "Origin" => "https://evil.example" }

    assert_response :forbidden
    assert_not_requested stub
  end

  # --- Legitimate traffic still forwards ---

  test "same-origin session request forwards to prometheus" do
    stub_request(:get, "http://localhost:9090/graph").to_return(status: 200, body: "Prometheus UI")
    sign_in

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
  end

  test "same-origin session request forwards a write to alertmanager" do
    silence_json = { comment: "real" }.to_json
    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
      .with(body: silence_json)
      .to_return(status: 200, body: '{"silenceID":"abc-123"}', headers: { "Content-Type" => "application/json" })
    sign_in

    post "/alertmanager/api/v2/silences",
      params: silence_json,
      headers: { "Content-Type" => "application/json", "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
    assert_requested stub
  end

  test "OTLP stays on its token path: no token is unauthorized, not forbidden" do
    post "/prometheus/api/v1/otlp/v1/metrics",
      headers: { "Content-Type" => "application/x-protobuf", "Sec-Fetch-Site" => "cross-site" }

    assert_response :unauthorized
  end

  # --- Tightened Fetch-Metadata policy ---

  test "same-site sub-resource POST is refused" do
    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
    sign_in

    post "/alertmanager/api/v2/silences",
      params: { comment: "sibling" }.to_json,
      headers: { "Content-Type" => "application/json", "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "cors" }

    assert_response :forbidden
    assert_not_requested stub
  end

  test "a session POST with no Fetch-Metadata and no Origin fails closed" do
    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
    sign_in

    post "/alertmanager/api/v2/silences",
      params: { comment: "old browser" }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :forbidden
    assert_not_requested stub
  end

  test "a same-site top-level GET navigation between our subdomains is allowed" do
    stub_request(:get, "http://localhost:9090/graph").to_return(status: 200, body: "Prometheus UI")
    sign_in

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "navigate" }

    assert_response :success
  end

  test "a normal query still forwards on the session path" do
    stub_request(:get, "http://localhost:9090/api/v1/query?query=up").to_return(status: 200, body: "{}")
    sign_in

    get "/prometheus/api/v1/query?query=up", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
  end
end
