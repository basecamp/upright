require "test_helper"
require "webmock/minitest"

class Upright::Probes::HTTPProbeTest < ActiveSupport::TestCase
  test "sends correct user agent" do
    stub = stub_request(:get, "https://example.com/")
      .with(headers: { "User-Agent" => Upright.configuration.user_agent })
      .to_return(status: 200)

    Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/").check

    assert_requested stub
  end

  test "returns true for 2xx response" do
    stub_request(:get, "https://example.com/").to_return(status: 200)

    result = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/").check

    assert result
  end

  test "returns true when expected_status matches" do
    stub_request(:get, "https://example.com/redirect").to_return(status: 301)

    probe = Upright::Probes::HTTPProbe.find_by(name: "Expected301")
    result = probe.check

    assert result
  end

  test "returns false when expected_status does not match" do
    stub_request(:get, "https://example.com/redirect").to_return(status: 200)

    probe = Upright::Probes::HTTPProbe.find_by(name: "Expected301")
    result = probe.check

    assert_not result
  end

  test "returns false for 4xx response" do
    stub_request(:get, "https://example.com/").to_return(status: 404)

    result = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/").check

    assert_not result
  end

  test "returns false for 5xx response" do
    stub_request(:get, "https://example.com/").to_return(status: 500)

    result = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/").check

    assert_not result
  end

  test "returns false on timeout" do
    stub_request(:get, "https://example.com/").to_timeout

    result = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/").check

    assert_not result
  end

  test "sends basic auth when credentials configured" do
    stub = stub_request(:get, "https://example.com/")
      .with(basic_auth: [ "user", "pass" ])
      .to_return(status: 200)

    probe = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/", basic_auth_credentials: "test_creds")
    probe.stubs(:credentials).returns({ username: "user", password: "pass" })

    probe.check

    assert_requested stub
  end

  test "uses proxy with authentication when configured" do
    probe = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/", proxy: "auth_proxy")
    probe.stubs(:proxy_credentials).returns({
      url: "http://proxy.example.com:8080",
      username: "proxyuser",
      password: "proxypass"
    })

    Typhoeus.expects(:get).with(
      "https://example.com/",
      has_entries(proxy: "http://proxy.example.com:8080", proxyuserpwd: "proxyuser:proxypass")
    ).returns(Typhoeus::Response.new(code: 200))

    probe.check
  end

  test "uses one of the proxies from proxies array" do
    probe = Upright::Probes::HTTPProbe.find_by(name: "MultiProxy")
    Rails.application.credentials.stubs(:dig).with(:proxies, :proxy_a).returns({ url: "http://a.example.com" })
    Rails.application.credentials.stubs(:dig).with(:proxies, :proxy_b).returns({ url: "http://b.example.com" })
    Rails.application.credentials.stubs(:dig).with(:proxies, :proxy_c).returns({ url: "http://c.example.com" })

    Typhoeus.expects(:get).with(
      "https://example.com/multi",
      has_entry(:proxy, any_of("http://a.example.com", "http://b.example.com", "http://c.example.com"))
    ).returns(Typhoeus::Response.new(code: 200))

    probe.check
  end

  test "records http response status metric" do
    stub_request(:get, "https://example.com/").to_return(status: 201)

    Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/").check

    assert_equal 201, yabeda_gauge_value(:http_response_status, name: "test", probe_target: "https://example.com/", probe_service: nil)
  end

  test "check_and_record creates result with ok status" do
    stub_request(:get, "https://example.com/").to_return(status: 200, body: "<html></html>")
    set_test_site
    probe = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/")
    probe.logger = null_logger

    assert_difference -> { Upright::ProbeResult.count } do
      probe.check_and_record
    end

    result = Upright::ProbeResult.last
    assert_equal "ok", result.status
    assert_equal "http", result.probe_type
    assert_equal "test", result.probe_name
    assert_equal "https://example.com/", result.probe_target
  end

  test "check_and_record creates fail result with exception artifact when check raises" do
    stub_request(:get, "https://example.com/").to_return(status: 200)
    set_test_site
    probe = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/")
    probe.logger = null_logger
    probe.stubs(:check).raises(RuntimeError.new("connection refused"))
    Rails.error.stubs(:report)

    probe.check_and_record

    result = Upright::ProbeResult.last
    assert_equal "fail", result.status
    assert_match(/RuntimeError: connection refused/, result.exception_report)
  end

  test "check_and_record attaches curl log and response as artifacts" do
    stub_request(:get, "https://example.com/").to_return(
      status: 200,
      body: '{"status": "ok"}',
      headers: { "Content-Type" => "application/json" }
    )
    set_test_site
    probe = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/")
    probe.logger = null_logger

    probe.check_and_record

    result = Upright::ProbeResult.last
    assert_equal 2, result.artifacts.count

    log_artifact = result.artifacts.find { |a| a.filename.to_s == "curl.log" }
    response_artifact = result.artifacts.find { |a| a.filename.to_s == "response.json" }

    assert_not_nil log_artifact
    assert_not_nil response_artifact
    assert_equal '{"status": "ok"}', response_artifact.download
  end

  test "stores HTML response bodies as plain text, never text/html" do
    stub_request(:get, "https://example.com/").to_return(
      status: 200,
      body: "<html><script>alert(1)</script></html>",
      headers: { "Content-Type" => "text/html" }
    )
    set_test_site
    probe = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/")
    probe.logger = null_logger

    probe.check_and_record

    result = Upright::ProbeResult.last
    response_artifact = result.artifacts.find { |a| a.filename.to_s.start_with?("response") }

    assert_not_nil response_artifact
    assert_equal "response.txt", response_artifact.filename.to_s
    assert_equal "text/plain", response_artifact.content_type
  end

  test "truncates oversized response bodies" do
    body = "a" * (Upright::Probes::HTTPProbe::MAX_STORED_BODY_BYTES + 1024)
    stub_request(:get, "https://example.com/").to_return(
      status: 200,
      body: body,
      headers: { "Content-Type" => "text/plain" }
    )
    set_test_site
    probe = Upright::Probes::HTTPProbe.new(name: "test", url: "https://example.com/")
    probe.logger = null_logger

    probe.check_and_record

    result = Upright::ProbeResult.last
    assert_equal "ok", result.status, "truncation must not affect probe success"

    response_artifact = result.artifacts.find { |a| a.filename.to_s.start_with?("response") }
    stored = response_artifact.download

    assert_operator stored.bytesize, :<=, Upright::Probes::HTTPProbe::MAX_STORED_BODY_BYTES + 100
    assert_match(/\[TRUNCATED/, stored)
  end

  private
    def null_logger
      Logger.new("/dev/null").tap do |l|
        l.define_singleton_method(:struct) { |_| }
      end
    end
end
