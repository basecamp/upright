require "test_helper"

class Upright::MetricsTest < ActiveSupport::TestCase
  test "labels every metric with the Rails environment" do
    assert_equal "test", Yabeda.default_tags[:environment]
  end
end
