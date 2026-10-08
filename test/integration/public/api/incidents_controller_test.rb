require "test_helper"

class Upright::Public::Api::IncidentsControllerTest < ActionDispatch::IntegrationTest
  include PublicApiHelper

  test "index includes updates, components and a shortlink" do
    incident = declare_incident title: "Example App is down", impact: "major"

    get "/api/v2/incidents.json"

    assert_response :success
    entry = json["incidents"].sole
    assert_equal incident.id.to_s, entry["id"]
    assert_equal "Example App is down", entry["name"]
    assert_equal "investigating", entry["status"]
    assert_equal "major", entry["impact"]
    assert_equal "http://#{host}/incidents/#{incident.id}", entry["shortlink"]
    assert_equal [ "example_app" ], entry["components"].map { |component| component["id"] }
    assert_equal [ "investigating" ], entry["incident_updates"].map { |update| update["status"] }
  end

  test "index leaves out internal-only incidents and maintenance" do
    declare_incident title: "Internal tools are down", service_codes: [ "internal_tools" ]
    schedule_maintenance starts_at: 1.hour.from_now, ends_at: 2.hours.from_now

    get "/api/v2/incidents.json"

    assert_empty json["incidents"]
  end
end
