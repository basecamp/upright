require "test_helper"

class Upright::Incidents::HistoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    on_subdomain :app
  end

  test "lists incidents and maintenances by month, newest first" do
    get upright.incidents_history_path

    assert_response :success
    assert_select ".incident-row", count: Upright::Incident.count
    assert_select ".incident-section__title", text: "June 2026"
  end

  test "filters by type" do
    get upright.incidents_history_path(kind: "maintenance")

    assert_select ".incident-row", count: Upright::Maintenance.count
    assert_select ".incident-row--maintenance", count: Upright::Maintenance.count
  end

  test "filters by service" do
    get upright.incidents_history_path(service: "example_app")

    assert_select ".incident-row", count: Upright::Incident.for_service("example_app").count
  end

  test "searches titles and update messages" do
    get upright.incidents_history_path(q: "investigating")

    assert_select ".incident-row__title", text: "Resolved outage"
    assert_select ".incident-row", count: 1
  end

  test "says when nothing matches" do
    get upright.incidents_history_path(q: "no such incident")

    assert_select ".incidents-empty__headline", text: "Nothing found"
  end

  test "the incidents page links to the full history" do
    get upright.incidents_path

    assert_select "a[href='#{upright.incidents_history_path}']", text: "All history"
  end
end
