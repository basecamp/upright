require "test_helper"

class JobsTest < ActionDispatch::IntegrationTest
  test "redirects a signed-out request for a jobs page to sign in" do
    on_subdomain "ams"

    get "/jobs"

    assert_redirected_to upright.new_admin_session_url(subdomain: "app")
    assert_equal request.url, session[:return_to]
  end
end
