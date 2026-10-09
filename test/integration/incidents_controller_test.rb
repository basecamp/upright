require "test_helper"

class Upright::IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    on_subdomain :app
  end

  test "creating an incident opens it" do
    post upright.incidents_path, params: { incident: incident_params }

    assert_redirected_to upright.edit_incident_path(Upright::Incident.last)
  end

  test "creating an incident without an affected service shows an error" do
    assert_no_difference -> { Upright::Incident.count } do
      post upright.incidents_path, params: { incident: incident_params(service_codes: [ "" ]) }
    end

    assert_response :unprocessable_entity
    assert_select ".incident-errors li", text: "Affected services must include at least one service"
  end

  test "the start time is prefilled to the minute so whole-minute times are valid" do
    travel_to Time.zone.parse("2026-10-09 14:29:17") do
      get upright.new_incident_path
    end

    assert_select "input[name='incident[starts_at]'][value='2026-10-09T14:29']"
  end

  test "the header of an active incident shows its status" do
    incident = Upright::Incident.create!(incident_params)

    get upright.edit_incident_path(incident)

    assert_select ".incident-form__eyebrow", text: "Incident · Investigating"
    assert_select ".incident-form--resolved", count: 0
  end

  test "the header of a resolved incident shows it is resolved" do
    get upright.edit_incident_path(upright_incidents(:reactive_resolved))

    assert_select ".incident-editor--resolved .incident-form--resolved .incident-form__eyebrow", text: "Incident · Resolved"
  end

  test "the message buttons explain that they don't change the status" do
    get upright.edit_incident_path(upright_incidents(:reactive_resolved))

    assert_select ".composer .field__hint", text: /doesn’t change the status/
  end

  private
    def incident_params(**overrides)
      { title: "Example App is down", impact: "critical", starts_at: Time.current, service_codes: [ "example_app" ] }.merge(overrides)
    end
end
