require "test_helper"

# Regression coverage for CVE-2026-67993 (login CSRF via the static_credentials
# callback). These tests must run with request forgery protection ENABLED — the
# suite otherwise disables it (see test/dummy/config/environments/test.rb), which
# would make every assertion below pass for the wrong reason.
class LoginCsrfTest < ActionDispatch::IntegrationTest
  setup do
    on_subdomain :app

    @forgery_protection_was = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    # test_mode lets us stand in a "valid" credential result without depending on
    # the configured password: the point under test is that CSRF/method guards
    # refuse the forged request even when the credentials would have been accepted.
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:static_credentials] = OmniAuth::AuthHash.new(
      provider: "static_credentials",
      uid: "admin",
      info: { email: "admin@localhost", name: "admin" }
    )
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection_was
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:static_credentials] = nil
  end

  test "a cross-site GET to the credential callback cannot plant a session" do
    get "/auth/static_credentials/callback", params: { username: "admin", password: "known-to-attacker" }

    assert_response :not_found
    assert_nil session[:user_info]
  end

  test "a HEAD to the credential callback cannot plant a session" do
    head "/auth/static_credentials/callback", params: { username: "admin", password: "known-to-attacker" }

    assert_response :not_found
    assert_nil session[:user_info]
  end

  test "a cross-origin POST without a valid authenticity token is refused" do
    post "/auth/static_credentials/callback", params: { username: "admin", password: "known-to-attacker" }

    assert_response :unprocessable_content
    assert_nil session[:user_info]
  end

  test "the same-origin sign-in form still signs in" do
    get upright.new_admin_session_path
    assert_response :success

    token = css_select("input[name='authenticity_token']").first&.[]("value")
    assert token.present?, "the sign-in form should carry a Rails authenticity token"

    post "/auth/static_credentials/callback",
      params: { username: "admin", password: "irrelevant-in-test-mode", authenticity_token: token }

    assert_redirected_to upright.root_path
    assert session[:user_info].present?
  end
end
