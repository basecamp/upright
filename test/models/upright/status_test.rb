require "test_helper"

class Upright::StatusTest < ActiveSupport::TestCase
  test "for returns operational when fully up" do
    assert_equal :operational, Upright::Status.for(1.0)
  end

  test "for returns nil when no measurement is available" do
    assert_nil Upright::Status.for(nil)
  end

  test "for returns degraded for minor failures" do
    assert_equal :degraded, Upright::Status.for(0.99)
  end

  test "for returns partial_outage for moderate failures" do
    assert_equal :partial_outage, Upright::Status.for(0.8)
  end

  test "for returns major_outage when below half" do
    assert_equal :major_outage, Upright::Status.for(0.4)
  end
end
