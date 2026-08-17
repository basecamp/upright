require "test_helper"

# Unit coverage for the proxy upstream URL builder (WP1 / F-01 / CVE-2026-25765).
# These assert the builder directly because the Rack test client (like production
# path normalization) can collapse a literal `//`, so the authority-override
# vector is only faithfully exercised against the method itself.
class ProxyPathSanitizationTest < ActiveSupport::TestCase
  UPSTREAM = "http://localhost:9090"

  setup { @controller = Upright::PrometheusProxyController.new }

  def build(raw)
    @controller.send(:upstream_url, UPSTREAM, raw)&.to_s
  end

  test "the upstream host and port always come from the configuration" do
    # Even a path that survives validation can only ever be a path on the
    # configured upstream — there is no request input for scheme/host/port.
    assert_equal "#{UPSTREAM}/api/v1/query", build("/api/v1/query")
  end

  test "rejects a protocol-relative authority override" do
    assert_nil build("//evil.example/steal")
    assert_nil build("//169.254.169.254/latest/meta-data/")
  end

  test "rejects path traversal" do
    assert_nil build("/api/v1/../../etc/passwd")
    assert_nil build("/..")
  end

  test "rejects characters outside the path set" do
    assert_nil build("/api/v1/query\nHost: evil")
    assert_nil build("/api/ query")
  end

  test "rejects a path with a null byte or broken encoding" do
    assert_nil build("/api/v1/query\0")
    assert_nil build("/api/\xC3(")
  end

  test "rejects percent-encoding in the path (double-encoding bypass)" do
    # %2f%2f -> // and %252f%252f -> %2f%2f -> // once the upstream decodes it;
    # rejecting any encoding in the path stops the authority/prefix bypass.
    assert_nil build("/%2f%2fevil.example/steal")
    assert_nil build("/%252d%252freload")
    assert_nil build("/api/%2e%2e/secret")
  end

  test "rejects a single-dot segment that a normalizing hop would collapse" do
    # /./-/reload -> /-/reload after normalization, bypassing the /-/ deny.
    assert_nil build("/./-/reload")
    assert_nil build("/api/./v1")
    assert_nil build("/.")
    assert_equal "#{UPSTREAM}/api/v1.json", build("/api/v1.json") # a dot inside a segment is fine
  end

  test "rejects an over-long query" do
    assert_nil build("/api/v1/query?" + ("a" * (Upright::ProxyAuthentication::MAX_UPSTREAM_QUERY + 1)))
  end

  test "rejects a malformed percent escape in the query" do
    assert_nil build("/api/v1/query?query=%zz")
  end

  test "passes a normal path and query through unchanged" do
    assert_equal "#{UPSTREAM}/api/v1/query?query=up", build("/api/v1/query?query=up")
    assert_equal "#{UPSTREAM}/graph", build("/graph")
    assert_equal "#{UPSTREAM}/graph/", build("/graph/")
    assert_equal "#{UPSTREAM}/", build("")
  end
end
