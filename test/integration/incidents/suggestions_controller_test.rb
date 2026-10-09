require "test_helper"

class Upright::Incidents::SuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    on_subdomain :app
  end

  test "suggests titles for a new incident on the chosen services" do
    get upright.incidents_suggestions_path(field: "title", incident: { service_codes: [ "example_app" ], impact: "critical" })

    assert_response :success
    assert_equal({ "text" => "Example App is down", "uses" => 0 }, response.parsed_body.last)
  end

  test "suggests maintenance titles when the form is set to maintenance" do
    get upright.incidents_suggestions_path(field: "title", maintenance: "true", incident: { service_codes: [ "example_app" ] })

    assert_equal "Example App maintenance", response.parsed_body.last["text"]
  end

  test "suggests messages for an incident's status" do
    incident = upright_incidents(:reactive_resolved)

    get upright.incident_suggestions_path(incident, field: "body", incident_update: { status: "resolved" })

    assert_equal "Example App is back up and operating normally.", response.parsed_body.last["text"]
  end

  test "an unknown status or impact falls back to the first status" do
    get upright.incidents_suggestions_path(field: "body", incident: { impact: "bogus" }, incident_update: { status: "bogus" })

    assert_response :success
    assert_equal "We are investigating the cause and will post updates here.", response.parsed_body.last["text"]
  end
end
