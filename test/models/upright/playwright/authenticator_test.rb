require "test_helper"

class Upright::Playwright::AuthenticatorTest < ActiveSupport::TestCase
  include MockPlaywrightHelper

  class TestAuthenticator < Upright::Playwright::Authenticator::Base
    attr_accessor :authenticated

    def signin_redirect_url = "https://example.com/"
    def signin_path = "/signin"
    def service_name = "test"

    private
      def authenticate
        @authenticated = true
      end
  end

  test "session_valid_on? returns true when not on signin path" do
    authenticator = TestAuthenticator.new
    page = MockPage.new

    assert authenticator.session_valid_on?(page)
  end

  test "authenticate_on sets page and runs authenticate" do
    authenticator = TestAuthenticator.new
    page = MockPage.new

    authenticator.authenticate_on(page)

    assert authenticator.authenticated
  end
end
