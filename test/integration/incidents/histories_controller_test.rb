require "test_helper"

class Upright::Incidents::HistoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    on_subdomain :app
  end

  test "the old history page redirects to the incidents page, keeping its filters" do
    get upright.incidents_history_path(kind: "maintenance", q: "database")

    assert_redirected_to upright.incidents_path(kind: "maintenance", q: "database")
    assert_response :moved_permanently
  end
end
