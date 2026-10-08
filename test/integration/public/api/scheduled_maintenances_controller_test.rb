require "test_helper"

class Upright::Public::Api::ScheduledMaintenancesControllerTest < ActionDispatch::IntegrationTest
  include PublicApiHelper

  test "index lists maintenances with their window and leaves out incidents" do
    maintenance = schedule_maintenance starts_at: 1.hour.from_now, ends_at: 2.hours.from_now
    declare_incident title: "Example App is down"

    get "/api/v2/scheduled-maintenances.json"

    assert_response :success
    entry = json["scheduled_maintenances"].sole
    assert_equal "scheduled", entry["status"]
    assert_equal "maintenance", entry["impact"]
    assert_equal maintenance.starts_at.utc.iso8601(3), entry["scheduled_for"]
    assert_equal maintenance.ends_at.utc.iso8601(3), entry["scheduled_until"]
  end
end
