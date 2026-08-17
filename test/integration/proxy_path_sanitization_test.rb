require "test_helper"

# Unit coverage for the proxy path lock (WP1 / F-01 / CVE-2026-25765). These
# assert the sanitizer directly because the Rack test client (like production
# path normalization) can collapse a literal `//`, so the authority-override
# vector is only faithfully exercised against the method itself.
class ProxyPathSanitizationTest < ActiveSupport::TestCase
  setup { @controller = Upright::PrometheusProxyController.new }

  def sanitize(raw)
    @controller.send(:sanitized_upstream_path, raw)
  end

  test "rejects a protocol-relative authority override" do
    assert_nil sanitize("//evil.example/steal")
    assert_nil sanitize("//169.254.169.254/latest/meta-data/")
  end

  test "rejects path traversal" do
    assert_nil sanitize("/api/v1/../../etc/passwd")
    assert_nil sanitize("/..")
  end

  test "rejects percent-encoding in the path (double-encoding bypass)" do
    assert_nil sanitize("/%2f%2fevil.example/steal")
    assert_nil sanitize("/%252d%252freload")
    assert_nil sanitize("/api/%2e%2e/secret")
  end

  test "rejects a single-dot segment that URI#merge would collapse" do
    assert_nil sanitize("/./-/reload")
    assert_nil sanitize("/api/./v1")
    assert_nil sanitize("/.")
    assert_equal "/api/v1.json", sanitize("/api/v1.json")
  end

  test "rejects characters outside the path set" do
    assert_nil sanitize("/api/v1/query\nHost: evil")
    assert_nil sanitize("/api/ query")
  end

  test "rejects a path with a null byte or broken encoding" do
    assert_nil sanitize("/api/v1/query\0")
    assert_nil sanitize("/api/\xC3(")
  end

  test "rejects an over-long query" do
    assert_nil sanitize("/api/v1/query?" + ("a" * (Upright::ProxyGuards::MAX_UPSTREAM_QUERY + 1)))
  end

  test "passes a normal path and query through unchanged" do
    assert_equal "/api/v1/query?query=up", sanitize("/api/v1/query?query=up")
    assert_equal "/graph", sanitize("/graph")
    assert_equal "/", sanitize("")
  end

  test "the built request must stay on the configured upstream host" do
    assert @controller.send(:upstream_host_ok?, "http://localhost:9090", "/api/v1/query")
    refute @controller.send(:upstream_host_ok?, "http://localhost:9090", "//evil.example/x")
  end
end
