require "test_helper"

class Upright::Public::Api::SummariesControllerTest < ActionDispatch::IntegrationTest
  include PublicApiHelper

  test "show combines the page, components, unresolved incidents, maintenances and status" do
    declare_incident title: "Example App is down"

    get "/api/v2/summary.json"

    assert_response :success
    assert_equal %w[ page components incidents scheduled_maintenances status ], json.keys
    assert_equal [ "Example App is down" ], json["incidents"].map { |incident| incident["name"] }
  end
end
