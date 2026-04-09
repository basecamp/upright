require "test_helper"

class Upright::ProbeTypeRegistryTest < ActiveSupport::TestCase
  setup do
    @registry = Upright::ProbeTypeRegistry.new
  end

  test "register adds a probe type" do
    @registry.register(:ftp_file, name: "FTP File", icon: "📂")

    assert_equal %w[ftp_file], @registry.types
  end

  test "register replaces an existing probe type with the same identifier" do
    @registry.register(:http, name: "HTTP", icon: "🌐")
    @registry.register(:http, name: "Custom HTTP", icon: "🔗")

    assert_equal %w[http], @registry.types
    assert_equal "Custom HTTP", @registry.find(:http).name
    assert_equal "🔗", @registry.find(:http).icon
  end

  test "register accepts string or symbol type identifiers" do
    @registry.register("ftp_file", name: "FTP File", icon: "📂")

    assert_equal "FTP File", @registry.find(:ftp_file).name
    assert_equal "FTP File", @registry.find("ftp_file").name
  end

  test "types returns registered type identifiers as strings" do
    @registry.register(:http, name: "HTTP", icon: "🌐")
    @registry.register(:smtp, name: "SMTP", icon: "✉️")

    assert_equal %w[http smtp], @registry.types
  end

  test "find returns nil for an unregistered type" do
    assert_nil @registry.find(:nonexistent)
  end

  test "each yields all registered probe types" do
    @registry.register(:http, name: "HTTP", icon: "🌐")
    @registry.register(:smtp, name: "SMTP", icon: "✉️")

    names = @registry.map(&:name)
    assert_equal %w[HTTP SMTP], names
  end

  test "built-in probe types are registered by the engine" do
    probe_types = Upright.probe_types

    assert_includes probe_types.types, "http"
    assert_includes probe_types.types, "playwright"
    assert_includes probe_types.types, "smtp"
    assert_includes probe_types.types, "traceroute"
  end

  test "registering via config.probe_types adds to the registry" do
    Upright.config.probe_types.register :test_probe, name: "Test", icon: "🧪"

    assert_includes Upright.probe_types.types, "test_probe"
    assert_equal "🧪", Upright.probe_types.find(:test_probe).icon
  ensure
    Upright.probe_types.unregister(:test_probe)
  end
end
