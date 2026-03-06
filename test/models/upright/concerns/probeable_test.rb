require "test_helper"

class Upright::ProbeableTest < ActiveSupport::TestCase
  class MinimalProbe
    include Upright::Probeable

    def probe_type = "test"
    def probe_target = "test"
    def on_check_recorded(_) = nil
  end

  class ProbeWithSeverityMethod < MinimalProbe
    def alert_severity = "critical"
  end

  class ProbeWithInvalidSeverityMethod < MinimalProbe
    def alert_severity = "urgent"
  end

  test "defaults to :high when alert_severity is not defined" do
    probe = MinimalProbe.new
    assert_equal :high, probe.probe_alert_severity
  end

  test "defaults to :high when alert_severity is nil" do
    probe = MinimalProbe.new
    probe.stubs(:alert_severity).returns(nil)
    assert_equal :high, probe.probe_alert_severity
  end

  test "returns :medium when alert_severity is set to medium in YAML" do
    probe = Upright::Probes::HTTPProbe.find_by(name: "MediumSeverity")
    assert_equal :medium, probe.probe_alert_severity
  end

  test "returns :high when alert_severity is set to high in YAML" do
    probe = Upright::Probes::HTTPProbe.find_by(name: "HighSeverity")
    assert_equal :high, probe.probe_alert_severity
  end

  test "returns :critical when alert_severity is set to critical in YAML" do
    probe = Upright::Probes::HTTPProbe.find_by(name: "CriticalSeverity")
    assert_equal :critical, probe.probe_alert_severity
  end

  test "falls back to :high for an unrecognised alert_severity in YAML" do
    probe = Upright::Probes::HTTPProbe.find_by(name: "InvalidSeverity")
    assert_equal :high, probe.probe_alert_severity
  end

  test "returns :critical when alert_severity method returns a valid value" do
    probe = ProbeWithSeverityMethod.new
    assert_equal :critical, probe.probe_alert_severity
  end

  test "falls back to :high when alert_severity method returns an invalid value" do
    probe = ProbeWithInvalidSeverityMethod.new
    assert_equal :high, probe.probe_alert_severity
  end
end
