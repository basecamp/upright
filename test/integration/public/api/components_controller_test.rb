require "test_helper"

class Upright::Public::Api::ComponentsControllerTest < ActionDispatch::IntegrationTest
  include PublicApiHelper

  test "index lists public services with their live status" do
    Upright::Service.any_instance.stubs(:live_status).returns(:partial_outage)

    get "/api/v2/components.json"

    assert_response :success
    assert_equal [ "example_app" ], json["components"].map { |component| component["id"] }
    assert_equal "partial_outage", json["components"].first["status"]
  end

  test "index shows maintenance while a window is open" do
    schedule_maintenance starts_at: 1.minute.ago, ends_at: 1.hour.from_now

    get "/api/v2/components.json"

    assert_equal "under_maintenance", json["components"].first["status"]
  end
end
