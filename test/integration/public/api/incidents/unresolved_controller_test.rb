require "test_helper"

class Upright::Public::Api::Incidents::UnresolvedControllerTest < ActionDispatch::IntegrationTest
  include PublicApiHelper

  test "index leaves out resolved incidents" do
    declare_incident(title: "Old outage").record_update(status: "resolved", body: "Fixed.")
    declare_incident title: "Current outage"

    get "/api/v2/incidents/unresolved.json"

    assert_response :success
    assert_equal [ "Current outage" ], json["incidents"].map { |incident| incident["name"] }
  end
end
