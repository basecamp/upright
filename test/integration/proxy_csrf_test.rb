require "test_helper"
require "webmock/minitest"

# Regression coverage for CVE-2026-67990 (proxy CSRF). A browser request on the
# session-cookie path must be refused when it originates cross-site, so a forged
# request can't ride the victim's Lax session cookie into upstream write/admin
# APIs. The bearer-token path (automation) stays exempt, and genuine same-origin
# calls from the embedded UI still forward.
class ProxyCsrfTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain :ams
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

  test "a null Origin on the session path is forbidden when Sec-Fetch is absent" do
    # A sandboxed iframe or a cross-origin redirect sends `Origin: null`.
    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
    sign_in

    post "/alertmanager/api/v2/silences",
      params: { comment: "forged" }.to_json,
      headers: { "Content-Type" => "application/json", "Origin" => "null" }

    assert_response :forbidden
    assert_not_requested stub
  end

  test "Rails token verification stays in the chain as a backstop for the gate" do
    # The gate refuses cross-site requests before verification is consulted. This
    # asserts the second layer is still there: with the gate out of the way, a
    # session POST carrying neither an authenticity token nor same-origin
    # provenance is still refused rather than forwarded.
    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
    Upright::AlertmanagerProxyController.any_instance.stubs(:block_cross_site_session_requests)
    sign_in

    with_forgery_protection do
      post "/alertmanager/api/v2/silences",
        params: { comment: "forged" }.to_json,
        headers: { "Content-Type" => "application/json", "Sec-Fetch-Site" => "cross-site" }
    end

    assert_response 422
    assert_not_requested stub
  end

  test "a same-origin session POST is verified without an authenticity token" do
    silence_json = { comment: "real" }.to_json
    stub = stub_request(:post, "http://localhost:9093/api/v2/silences")
      .with(body: silence_json)
      .to_return(status: 200, body: '{"silenceID":"abc-123"}', headers: { "Content-Type" => "application/json" })
    sign_in

    with_forgery_protection do
      post "/alertmanager/api/v2/silences",
        params: silence_json,
        headers: { "Content-Type" => "application/json", "Sec-Fetch-Site" => "same-origin" }
    end

    assert_response :success
    assert_requested stub
  end

  test "a token-authenticated write is verified without an authenticity token" do
    stub = stub_request(:post, "http://localhost:9090/api/v1/otlp/v1/metrics").to_return(status: 200)

    with_forgery_protection do
      post "/prometheus/api/v1/otlp/v1/metrics",
        headers: { "Authorization" => "Bearer test-token", "Content-Type" => "application/x-protobuf" }
    end

    assert_response :success
    assert_requested stub
  end

  test "a non-bearer Authorization header buys no exemption from the gate" do
    stub = stub_request(:get, "http://localhost:9090/-/reload")
    sign_in

    get "/prometheus/-/reload",
      headers: { "Authorization" => "Basic #{Base64.strict_encode64("user:pass")}", "Sec-Fetch-Site" => "cross-site" }

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

  test "token-authenticated automation is exempt from the cross-site check" do
    stub_request(:get, "http://localhost:9090/api/v1/query?query=up").to_return(status: 200, body: "{}")

    get "/prometheus/api/v1/query?query=up",
      headers: { "Authorization" => "Bearer test-token", "Sec-Fetch-Site" => "cross-site" }

    assert_response :success
  end

  # --- WP4: tightened Fetch-Metadata policy ---

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

  test "a session GET with no provenance headers fails closed" do
    reload = stub_request(:get, "http://localhost:9090/-/reload")
    sign_in

    get "/prometheus/-/reload"

    assert_response :forbidden
    assert_not_requested reload
  end

  test "a same-site request is refused (a sibling domain is same-site, not same-origin)" do
    stub = stub_request(:get, "http://localhost:9090/graph")
    sign_in

    get "/prometheus/graph", headers: { "Sec-Fetch-Site" => "same-site", "Sec-Fetch-Mode" => "navigate" }

    assert_response :forbidden
    assert_not_requested stub
  end

  # --- WP1: SSRF path lock (F-01 / CVE-2026-25765). The path-authority-override
  # vector lives at the Faraday layer (Rack collapses a literal `//` before the
  # controller), so the sanitizer is unit-tested directly in
  # proxy_path_sanitization_test.rb. Here we cover the token/forwarding behaviour. ---

  test "a token cannot drive a destructive upstream endpoint" do
    reload = stub_request(:get, "http://localhost:9090/-/reload")

    get "/prometheus/-/reload", headers: { "Authorization" => "Bearer test-token" }

    assert_response :forbidden
    assert_not_requested reload
  end

  test "a normal query still forwards on the session path" do
    stub_request(:get, "http://localhost:9090/api/v1/query?query=up").to_return(status: 200, body: "{}")
    sign_in

    get "/prometheus/api/v1/query?query=up", headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :success
  end
end
