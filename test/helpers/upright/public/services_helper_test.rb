require "test_helper"

class Upright::Public::ServicesHelperTest < ActionView::TestCase
  test "no data yields nil" do
    assert_nil uptime_percentage_label([])
  end

  test "a flawless window reads as a bare 100%" do
    assert_equal "100%", uptime_percentage_label([ 1.0, 1.0, 1.0 ])
  end

  test "a tiny outage never rounds up to 100%" do
    # One 1-minute outage over 90 days ≈ 99.99923% — must not display as 100%.
    fractions = [ 1.0 - 1.0 / 1440 ] + Array.new(89, 1.0)
    assert_equal "99.999%", uptime_percentage_label(fractions)
  end

  test "always pads to three decimals below 100%" do
    assert_equal "99.500%", uptime_percentage_label([ 0.995 ])
    assert_equal "99.800%", uptime_percentage_label([ 0.998 ])
  end

  test "floors rather than rounds to three decimals" do
    assert_equal "99.999%", uptime_percentage_label([ 0.9999995 ])
  end
end
