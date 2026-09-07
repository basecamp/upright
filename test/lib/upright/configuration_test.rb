require "test_helper"

class Upright::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = Upright::Configuration.new
    @config.hostname = "upright.example.com"
  end

  # Assigning a hostname rewrites Rails.application.config.hosts, so put the
  # dummy app's own hostname back afterwards.
  teardown do
    Upright.configuration.hostname = "upright.localhost"
  end

  test "trace_viewer_url accepts an isolated origin" do
    @config.trace_viewer_url = "https://traces.example.net/index.html"

    assert_equal "https://traces.example.net/index.html", @config.trace_viewer_url
  end

  test "trace_viewer_url defaults to upstream's hosted viewer" do
    assert_equal "https://trace.playwright.dev/", @config.trace_viewer_url
    assert_equal "https://trace.playwright.dev", @config.trace_viewer_origin
  end

  test "TRACE_VIEWER_URL overrides the default" do
    with_env("TRACE_VIEWER_URL" => "https://traces.example.net/index.html") do
      assert_equal "https://traces.example.net/index.html", Upright::Configuration.new.trace_viewer_url
    end
  end

  test "assigning nil leaves traces download-only" do
    @config.trace_viewer_url = nil

    assert_nil @config.trace_viewer_url
    assert_nil @config.trace_viewer_origin
  end

  test "trace_viewer_url rejects the configured hostname and its subdomains" do
    [ "https://upright.example.com/trace-viewer/", "https://traces.upright.example.com/" ].each do |url|
      assert_raises Upright::ConfigurationError do
        @config.trace_viewer_url = url
      end
    end
  end

  test "trace_viewer_url rejects DNS-equivalent spellings of the configured hostname" do
    [ "https://UPRIGHT.EXAMPLE.COM/", "https://upright.example.com./", "https://Traces.Upright.Example.Com/" ].each do |url|
      assert_raises Upright::ConfigurationError do
        @config.trace_viewer_url = url
      end
    end
  end

  test "trace_viewer_url rejects anything that isn't an http(s) URL with a host" do
    [ "/trace-viewer/index.html", "//traces.example.net/viewer", "file:///tmp/viewer", "nonsense" ].each do |url|
      assert_raises Upright::ConfigurationError do
        @config.trace_viewer_url = url
      end
    end
  end

  test "the machine tokens read from the environment by default" do
    with_env("PROMETHEUS_OTLP_TOKEN" => "otlp-token", "METRICS_READ_TOKEN" => "read-token") do
      assert_equal "otlp-token", @config.otlp_token
      assert_equal "read-token", @config.metrics_read_token
    end
  end

  test "verify_machine_tokens names every missing token" do
    with_env("PROMETHEUS_OTLP_TOKEN" => nil, "METRICS_READ_TOKEN" => nil) do
      error = assert_raises(Upright::ConfigurationError) { @config.verify_machine_tokens }
      assert_match "PROMETHEUS_OTLP_TOKEN and METRICS_READ_TOKEN must be set", error.message

      @config.otlp_token = "otlp-token"
      error = assert_raises(Upright::ConfigurationError) { @config.verify_machine_tokens }
      assert_match(/\AMETRICS_READ_TOKEN must be set/, error.message)
    end
  end

  test "verify_machine_tokens refuses one value for both jobs" do
    @config.otlp_token = "same"
    @config.metrics_read_token = "same"

    error = assert_raises(Upright::ConfigurationError) { @config.verify_machine_tokens }
    assert_match "must differ", error.message
  end

  test "verify_machine_tokens passes two distinct tokens" do
    @config.otlp_token = "otlp-token"
    @config.metrics_read_token = "read-token"

    assert_nothing_raised { @config.verify_machine_tokens }
  end

  test "proxy_token is refused with directions to its replacements" do
    error = assert_raises(Upright::ConfigurationError) { @config.proxy_token = "token" }

    assert_match "config.otlp_token", error.message
    assert_match "config.metrics_read_token", error.message
  end

  test "trace_viewer_origin drops a default port and keeps an explicit one" do
    @config.trace_viewer_url = "https://traces.example.net/index.html"
    assert_equal "https://traces.example.net", @config.trace_viewer_origin

    @config.trace_viewer_url = "http://traces.localhost:4173/index.html"
    assert_equal "http://traces.localhost:4173", @config.trace_viewer_origin
  end
end
