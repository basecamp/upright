require "test_helper"

class Upright::Public::ApiTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain Upright.configuration.public_status_subdomain
    Upright.configuration.stubs(:public_status_json_enabled).returns(true)
    Upright::Service.any_instance.stubs(:live_status).returns(:operational)
    Upright::Service.any_instance.stubs(:current_outage_started_at).returns(nil)
    Upright::Incident.destroy_all
  end

  test "is not found unless enabled" do
    Upright.configuration.stubs(:public_status_json_enabled).returns(false)

    get "/api/v2/summary.json"

    assert_response :not_found
  end

  test "status reports the overall indicator with a short public cache" do
    get "/api/v2/status.json"

    assert_response :success
    assert_match %r{application/json}, response.content_type
    assert_equal "max-age=15, public", response.headers["Cache-Control"]
    assert_equal({ "indicator" => "none", "description" => "All Systems Operational" }, json["status"])
    assert_equal Upright.configuration.public_status_title, json.dig("page", "name")
  end

  test "status reflects an active incident" do
    declare_incident title: "Example App is down", impact: "critical"

    get "/api/v2/status.json"

    assert_equal "critical", json.dig("status", "indicator")
  end

  test "components list public services only" do
    Upright::Service.any_instance.stubs(:live_status).returns(:partial_outage)

    get "/api/v2/components.json"

    assert_equal [ "example_app" ], json["components"].map { |component| component["id"] }
    assert_equal "partial_outage", json["components"].first["status"]
  end

  test "components show maintenance while a window is open" do
    Upright::Maintenance.create! title: "Planned failover", starts_at: 1.minute.ago, ends_at: 1.hour.from_now, service_codes: [ "example_app" ]

    get "/api/v2/components.json"

    assert_equal "under_maintenance", json["components"].first["status"]
  end

  test "incidents include updates, components and a shortlink" do
    incident = declare_incident title: "Example App is down", impact: "major"

    get "/api/v2/incidents.json"

    entry = json["incidents"].sole
    assert_equal incident.id.to_s, entry["id"]
    assert_equal "Example App is down", entry["name"]
    assert_equal "investigating", entry["status"]
    assert_equal "major", entry["impact"]
    assert_equal "http://#{host}/incidents/#{incident.id}", entry["shortlink"]
    assert_equal [ "example_app" ], entry["components"].map { |component| component["id"] }
    assert_equal [ "investigating" ], entry["incident_updates"].map { |update| update["status"] }
  end

  test "incidents leave out internal-only incidents and maintenance" do
    declare_incident title: "Internal tools are down", service_codes: [ "internal_tools" ]
    Upright::Maintenance.create! title: "Planned failover", starts_at: 1.hour.from_now, ends_at: 2.hours.from_now, service_codes: [ "example_app" ]

    get "/api/v2/incidents.json"

    assert_empty json["incidents"]
  end

  test "unresolved incidents leave out resolved ones" do
    declare_incident(title: "Old outage").record_update(status: "resolved", body: "Fixed.")
    declare_incident title: "Current outage"

    get "/api/v2/incidents/unresolved.json"

    assert_equal [ "Current outage" ], json["incidents"].map { |incident| incident["name"] }
  end

  test "scheduled maintenances include the window" do
    maintenance = Upright::Maintenance.create! title: "Planned failover", starts_at: 1.hour.from_now, ends_at: 2.hours.from_now, service_codes: [ "example_app" ]

    get "/api/v2/scheduled-maintenances/upcoming.json"

    entry = json["scheduled_maintenances"].sole
    assert_equal "scheduled", entry["status"]
    assert_equal "maintenance", entry["impact"]
    assert_equal maintenance.starts_at.utc.iso8601(3), entry["scheduled_for"]
    assert_equal maintenance.ends_at.utc.iso8601(3), entry["scheduled_until"]

    get "/api/v2/scheduled-maintenances/active.json"
    assert_empty json["scheduled_maintenances"]
  end

  test "summary combines the page, components, unresolved incidents, maintenances and status" do
    declare_incident title: "Example App is down"

    get "/api/v2/summary.json"

    assert_equal %w[ page components incidents scheduled_maintenances status ], json.keys
    assert_equal [ "Example App is down" ], json["incidents"].map { |incident| incident["name"] }
  end

  test "is served as JSON whatever the Accept header asks for" do
    get "/api/v2/status.json", headers: { "Accept" => "text/html" }

    assert_response :success
    assert_match %r{application/json}, response.content_type
  end

  private
    def json
      response.parsed_body
    end

    def declare_incident(title:, impact: "minor", service_codes: [ "example_app" ])
      Upright::Incident.create! title: title, impact: impact, starts_at: 1.hour.ago, service_codes: service_codes
    end
end
