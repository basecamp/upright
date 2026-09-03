require "test_helper"

class Upright::Public::IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup { on_subdomain Upright.configuration.public_status_subdomain }

  test "incident detail never shows the author" do
    incident = upright_incidents(:reactive_resolved)
    assert_equal "Lewis Buckley", incident.created_by

    get upright.public_incident_path(incident)

    assert_response :success
    assert_no_match(/Lewis Buckley/, response.body)
  end

  test "returns 404 for an incident that affects only internal services" do
    incident = declare_incident title: "Internal tools are down", service_codes: [ "internal_tools" ]

    get upright.public_incident_path(incident)

    assert_response :not_found
  end

  test "returns 404 for an incident not tagged with any service" do
    incident = declare_incident title: "Untagged incident"

    get upright.public_incident_path(incident)

    assert_response :not_found
  end

  test "shows a public-facing incident without naming its internal services" do
    incident = declare_incident title: "Widespread slowness", service_codes: [ "example_app", "internal_tools" ]

    get upright.public_incident_path(incident)

    assert_response :success
    assert_match "Example App", response.body
    assert_no_match(/Internal Tools/, response.body)
  end

  private
    def declare_incident(title:, service_codes: [])
      Upright::Incident.create! title: title, impact: "critical",
        starts_at: 1.hour.ago, service_codes: service_codes
    end
end
