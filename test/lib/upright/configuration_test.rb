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

  test "trace_viewer_url is blank by default" do
    assert_nil @config.trace_viewer_url
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

  test "trace_viewer_origin drops a default port and keeps an explicit one" do
    @config.trace_viewer_url = "https://traces.example.net/index.html"
    assert_equal "https://traces.example.net", @config.trace_viewer_origin

    @config.trace_viewer_url = "http://traces.localhost:4173/index.html"
    assert_equal "http://traces.localhost:4173", @config.trace_viewer_origin
  end

  test "trace_viewer_origin is nil with no viewer configured" do
    assert_nil @config.trace_viewer_origin
  end
end
