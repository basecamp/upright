require "test_helper"

class Upright::IncidentAutoReportingTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 9, 1, 12)
    @service = Upright::Service.find_by!(code: "example_app")
  end

  test "creates a system-authored incident with the mapped impact and down template" do
    stub_degraded(status: :partial_outage, started_at: 10.minutes.ago)

    assert_difference -> { Upright::Incident.count }, 1 do
      Upright::Incident.report_downtime
    end

    incident = Upright::Incident.order(:id).last
    assert incident.auto_created?
    assert_equal "System", incident.created_by
    assert_equal "major", incident.impact
    assert_equal 10.minutes.ago, incident.starts_at
    assert_equal [ @service.code ], incident.service_codes
    assert_equal "Example App is down. We are investigating.", incident.updates.first.body
  end

  test "updates an existing incident without duplicating, escalates impact, and never downgrades" do
    stub_degraded(status: :degraded)
    Upright::Incident.report_downtime
    incident = Upright::Incident.order(:id).last

    travel 30.seconds
    stub_degraded(status: :major_outage)
    assert_no_difference -> { Upright::Incident.count } do
      Upright::Incident.report_downtime
    end
    assert_equal "critical", incident.reload.impact
    assert_equal Time.current, incident.last_seen_down_at

    travel 30.seconds
    stub_degraded(status: :degraded)
    Upright::Incident.report_downtime
    assert_equal "critical", incident.reload.impact
  end

  test "a manual incident suppresses auto-creation and is never auto-resolved" do
    incident = Upright::Incident.create!(title: "Manual outage", impact: "minor",
      starts_at: Time.current, service_codes: [ @service.code ])
    stub_degraded(status: :degraded)

    assert_no_difference -> { Upright::Incident.count } do
      Upright::Incident.report_downtime
    end
    assert_equal Time.current, incident.reload.last_seen_down_at

    travel Upright::Incidents::AutoReporting::RESOLVE_DELAY
    Upright::Service.stubs(:degraded).returns([])
    Upright::Incident.report_downtime
    assert_nil incident.reload.resolved_at
  end

  test "resolves only after continuous recovery and posts the back-up template" do
    stub_degraded(status: :degraded)
    Upright::Incident.report_downtime
    incident = Upright::Incident.order(:id).last

    Upright::Service.stubs(:degraded).returns([])
    travel Upright::Incidents::AutoReporting::RESOLVE_DELAY - 1.second
    Upright::Incident.report_downtime
    assert_nil incident.reload.resolved_at

    travel 1.second
    Upright::Incident.report_downtime
    assert_equal Time.current, incident.reload.resolved_at
    assert_equal "Example App is back up and operating normally.", incident.updates.first.body
  end

  test "reuses the incident when the service degrades again during the recovery delay" do
    stub_degraded(status: :degraded)
    Upright::Incident.report_downtime
    incident = Upright::Incident.order(:id).last

    Upright::Service.stubs(:degraded).returns([])
    travel 4.minutes
    Upright::Incident.report_downtime

    travel 30.seconds
    stub_degraded(status: :degraded)
    assert_no_difference -> { Upright::Incident.count } do
      Upright::Incident.report_downtime
    end
    assert_equal Time.current, incident.reload.last_seen_down_at
    assert_nil incident.resolved_at
  end

  test "does not report a service excluded from the degraded list by maintenance" do
    Upright::Service.stubs(:degraded).returns([])

    assert_no_difference -> { Upright::Incident.count } do
      Upright::Incident.report_downtime
    end
  end

  private
    def stub_degraded(status:, started_at: nil)
      Upright::Service.stubs(:degraded).returns([ { service: @service, status: status, started_at: started_at } ])
    end
end
