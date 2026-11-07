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

  test "static credentials sign in stacks its labelled fields above the button" do
    on_subdomain "app"
    get upright.new_admin_session_path

    assert_response :success
    assert_select ".sign-in-box form.sign-in-form" do
      assert_select ".field", 2
      assert_select ".field label.field__label[for=username] + input.field__input#username"
      assert_select ".field label.field__label[for=password] + input.field__input#password[type=password]"
      assert_select "input.btn[type=submit][value='Sign in']"
    end
  end

  test "a provider's sign in keeps its lone button outside the stacked form" do
    on_subdomain "app"
    with_auth_provider(:openid_connect) { get upright.new_admin_session_path }

    assert_response :success
    assert_select ".sign-in-box form.button_to button.btn", text: "Sign in"
    assert_select ".sign-in-form", 0
  end

  test "session routes not accessible from site subdomain" do
    on_subdomain "ams"
    get upright.new_admin_session_path

    assert_response :not_found
  end

  private
    def with_auth_provider(provider)
      previous = Upright.configuration.auth_provider
      Upright.configuration.auth_provider = provider
      yield
    ensure
      Upright.configuration.auth_provider = previous
    end
end
