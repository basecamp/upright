require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "creates session from OAuth2 callback" do
    sign_in

    assert_redirected_to upright.root_path
    assert session[:user_info].present?
    assert_equal "test@example.com", session[:user_info][:email]
    assert_equal "Test User", session[:user_info][:name]
  end

  test "destroys session on sign out" do
    sign_in

    delete upright.session_path
    assert_redirected_to upright.root_path
    assert_nil session[:user_info]

    follow_redirect!
    assert_redirected_to upright.new_admin_session_url(subdomain: "app")
  end

  test "returns to the page that sent you to the login" do
    on_subdomain "ams"
    get upright.prometheus_path, headers: { "Sec-Fetch-Site" => "same-origin" }

    sign_in

    assert_redirected_to "http://ams.#{Upright.configuration.hostname}#{upright.prometheus_path}"
  end

  test "session routes not accessible from site subdomain" do
    on_subdomain "ams"
    get upright.new_admin_session_path

    assert_response :not_found
  end
end
