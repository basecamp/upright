require "test_helper"

class Upright::IncidentReportTest < ActionDispatch::IntegrationTest
  setup do
    @incident = upright_incidents(:reactive_resolved)
  end

  test "an incident's admin page has a report form" do
    sign_in
    on_subdomain :app

    get upright.edit_incident_path(@incident)

    assert_select "form[action=?] textarea[name=?]", upright.incident_path(@incident), "incident[report]"
  end

  test "a maintenance's admin page has no report form" do
    sign_in
    on_subdomain :app

    get upright.edit_incident_path(upright_incidents(:upcoming))

    assert_select "textarea[name=?]", "incident[report]", count: 0
  end

  test "saving the report keeps the incident's other details" do
    sign_in
    on_subdomain :app

    patch upright.incident_path(@incident), params: { incident: { report: "A database failover took longer than expected." } }

    assert_redirected_to upright.edit_incident_path(@incident)
    @incident.reload
    assert_equal "A database failover took longer than expected.", @incident.report
    assert_equal [ "example_app" ], @incident.service_codes
    assert_equal "Resolved outage", @incident.title
  end

  test "the public incident page shows the report above the timeline" do
    @incident.update!(report: "A database failover took longer than expected.\n\nWe are shortening the failover timeout.")
    on_subdomain Upright.configuration.public_status_subdomain

    get upright.public_incident_path(@incident)

    assert_select ".incident-detail__report + .incident-detail__timeline"
    assert_select ".incident-detail__report h2", text: "Post-incident report"
    assert_select ".incident-detail__report p", count: 2
    assert_select ".incident-detail__report p", text: "We are shortening the failover timeout."
  end

  test "the public incident page has no report section until there is a report" do
    on_subdomain Upright.configuration.public_status_subdomain

    get upright.public_incident_path(@incident)

    assert_select ".incident-detail__report", count: 0
  end
end
