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

  test "trace_viewer_url rejects a relative URL" do
    assert_raises Upright::ConfigurationError do
      @config.trace_viewer_url = "/trace-viewer/index.html"
    end
  end

  test "trace_viewer_url is rechecked when the hostname is assigned later" do
    config = Upright::Configuration.new
    config.trace_viewer_url = "https://traces.example.net/index.html"

    assert_raises Upright::ConfigurationError do
      config.hostname = "example.net"
    end
  end
end
