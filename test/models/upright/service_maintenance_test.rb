require "test_helper"

class Upright::ServiceMaintenanceTest < ActiveSupport::TestCase
  setup { travel_to Time.utc(2026, 6, 15, 12) }

  test "maintenance_active? is true while a covering window is in progress" do
    maintain "example_app"

    assert Upright::Service.find_by(code: "example_app").maintenance_active?
    assert_not Upright::Service.find_by(code: "internal_tools").maintenance_active?
  end

  test "degraded suppresses a service that is under maintenance" do
    maintain "example_app"
    stub_live_status :major_outage
    Upright::Service.any_instance.stubs(:current_outage_started_at).returns(nil)

    codes = Upright::Service.degraded.map { |outage| outage.service.code }

    assert_not_includes codes, "example_app"
    assert_includes codes, "internal_tools"
  end

  test "overall_status reads maintenance when the only down services are under maintenance" do
    maintain "example_app"
    maintain "internal_tools", using: :started_scheduled
    stub_live_status :major_outage

    assert_equal :maintenance, Upright::Service.overall_status
  end

  test "a real outage on another service still outranks maintenance" do
    maintain "example_app"
    stub_live_status :major_outage

    assert_equal :major_outage, Upright::Service.overall_status
  end

  test "an active incident raises the overall status even when probes are green" do
    raise_incident impact: "critical"
    stub_live_status :operational

    assert_equal :major_outage, Upright::Service.overall_status
  end

  test "overall status takes the worse of probe status and incident impact" do
    raise_incident impact: "minor"
    stub_live_status :major_outage

    assert_equal :major_outage, Upright::Service.overall_status
  end

  test "export_service_metrics reports 1 for maintained services and 0 otherwise" do
    maintain "example_app"

    Upright::Maintenance.export_service_metrics

    assert_equal 1, yabeda_gauge_value(:service_under_maintenance, probe_service: "example_app")
    assert_equal 0, yabeda_gauge_value(:service_under_maintenance, probe_service: "internal_tools")
  end

  test "export_service_metrics arms suppression before a window opens but not too early" do
    upright_incidents(:upcoming).update!(starts_at: 30.seconds.from_now, service_codes: [ "example_app" ])

    Upright::Maintenance.export_service_metrics
    assert_equal 1, yabeda_gauge_value(:service_under_maintenance, probe_service: "example_app")

    upright_incidents(:upcoming).update!(starts_at: 5.minutes.from_now)
    Upright::Maintenance.export_service_metrics
    assert_equal 0, yabeda_gauge_value(:service_under_maintenance, probe_service: "example_app")
  end

  private
    def maintain(code, using: :in_progress)
      upright_incidents(using).update!(service_codes: [ code ])
    end

    def raise_incident(impact:, code: "example_app")
      upright_incidents(:reactive_resolved).update!(impact: impact, status: "investigating",
        starts_at: 1.hour.ago, resolved_at: nil, service_codes: [ code ])
    end

    def stub_live_status(status)
      Upright::Service.any_instance.stubs(:live_status).returns(status)
    end
end
