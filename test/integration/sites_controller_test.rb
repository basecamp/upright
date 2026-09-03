require "test_helper"

class SitesControllerTest < ActionDispatch::IntegrationTest
  test "redirects from no subdomain to app subdomain" do
    on_subdomain nil

    get upright.root_path

    assert_redirected_to upright.root_url(subdomain: "app")
  end

  test "shows sites index on app subdomain without redirect loop" do
    on_subdomain "app"
    sign_in

    get upright.root_path

    assert_response :success
    assert_equal "sites", @controller.controller_name
  end

  test "admin pages load the application entry point with its modules preloaded" do
    on_subdomain "app"
    sign_in

    get upright.root_path

    assert_response :success
    assert_match %(import "application"), response.body
    assert_match %r{<link rel="modulepreload" href="[^"]*turbo}, response.body
    assert_match %r{<link rel="modulepreload" href="[^"]*local-time}, response.body
  end
end
