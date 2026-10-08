require "test_helper"

class Upright::Public::Api::ScheduledMaintenances::ActiveControllerTest < ActionDispatch::IntegrationTest
  include PublicApiHelper

  test "index lists maintenances in progress" do
    schedule_maintenance starts_at: 1.hour.from_now, ends_at: 2.hours.from_now
    schedule_maintenance starts_at: 1.minute.ago, ends_at: 1.hour.from_now

    get "/api/v2/scheduled-maintenances/active.json"

    assert_response :success
    assert_equal 1, json["scheduled_maintenances"].size
    assert_operator Time.iso8601(json["scheduled_maintenances"].sole["scheduled_for"]), :<, Time.current
  end
end
