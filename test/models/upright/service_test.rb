require "test_helper"

class Upright::ServiceTest < ActiveSupport::TestCase
  test "loads services from config/services.yml" do
    codes = Upright::Service.all.map(&:code)

    assert_includes codes, "example_app"
    assert_includes codes, "internal_tools"
  end

  test "find_by code returns the matching service" do
    service = Upright::Service.find_by(code: "example_app")

    assert_equal "Example App", service.name
  end

  test "probe_results scopes ProbeResult by probe_service" do
    Upright::ProbeResult.create!(
      probe_type: :http, probe_name: "Linked", probe_target: "https://example.com",
      probe_service: "example_app", duration: 0.1, status: :ok
    )
    Upright::ProbeResult.create!(
      probe_type: :http, probe_name: "Unlinked", probe_target: "https://example.com",
      probe_service: "other", duration: 0.1, status: :ok
    )

    service = Upright::Service.find_by(code: "example_app")

    assert_equal [ "Linked" ], service.probe_results.pluck(:probe_name)
  end

  test "probes returns probe instances matching the service code" do
    service = Upright::Service.find_by(code: "example_app")

    klass = Class.new do
      include Upright::Probeable
      attr_reader :name, :probe_service
      def initialize(name, service); @name, @probe_service = name, service; end
      def self.all; @all ||= []; end
      def probe_type = "fake"
      def probe_target = name
      def on_check_recorded(_); end
    end

    klass.all << klass.new("a", "example_app")
    klass.all << klass.new("b", "other")

    matched = service.probes.select { |p| p.is_a?(klass) }
    assert_equal [ "a" ], matched.map(&:name)
  ensure
    Upright::Probeable.probe_classes -= [ klass ] if klass
  end
end
