require "test_helper"

class UprightTest < ActiveSupport::TestCase
  test "version number" do
    assert Upright::VERSION
  end

  test "environment_matcher scopes deployed queries, nil locally" do
    assert_equal %(environment="production"), with_rails_env("production") { Upright.environment_matcher }
    assert_equal %(environment="staging"), with_rails_env("staging") { Upright.environment_matcher }
    assert_nil with_rails_env("development") { Upright.environment_matcher }
    assert_nil with_rails_env("test") { Upright.environment_matcher }
  end
end
