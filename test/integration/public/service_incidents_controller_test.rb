require "test_helper"

class Upright::Public::ServiceIncidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain Upright.configuration.public_status_subdomain
    Upright::Service.any_instance.stubs(:live_status).returns(:operational)
    Upright::Service.any_instance.stubs(:current_outage_started_at).returns(nil)
  end

  test "index renders a public service and its incident history" do
    past = Upright::Incident.create!(title: "Example App is on fire", impact: "major",
      starts_at: 1.hour.ago, service_codes: [ "example_app" ])
    past.record_update(status: "resolved", body: "Example App is healthy again.")
    Upright::Incident.create!(title: "Internal tools are down", impact: "critical",
      starts_at: 1.hour.ago, service_codes: [ "internal_tools" ])

    get upright.public_service_incidents_path("example_app")

    assert_response :success
    assert_equal "max-age=15, public", response.headers["Cache-Control"]
    assert_select "h1", text: "Example App"
    assert_select "a[href='#{upright.public_incident_path(past)}']", text: /Example App is on fire/
    assert_match "Example App is healthy again.", response.body
    assert_no_match(/Internal tools are down/, response.body)
  end

  test "index returns not found for internal and unknown services" do
    get upright.public_service_incidents_path("internal_tools")
    assert_response :not_found

    get upright.public_service_incidents_path("missing")
    assert_response :not_found
  end
end
