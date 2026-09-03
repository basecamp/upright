require "test_helper"

class Upright::Service::DailyStatusTest < ActiveSupport::TestCase
  test "an operational day states uptime without a downtime clause" do
    day = day_with(uptime_fraction: 1.0)
    assert_equal "100.00% uptime", day.detail
  end

  test "a downtime clause reports whole minutes" do
    day = day_with(uptime_fraction: 1 - 5.0 / 1440)
    assert_equal "99.65% uptime · 5 mins down", day.detail
  end

  test "one minute is singular" do
    day = day_with(uptime_fraction: 1 - 1.0 / 1440)
    assert_equal "99.93% uptime · 1 min down", day.detail
  end

  test "sub-minute downtime reads as less than a minute" do
    day = day_with(uptime_fraction: 0.9999)
    assert_equal "99.99% uptime · <1 min down", day.detail
  end

  test "today carries a live status but no fraction" do
    day = Upright::Service::DailyStatus.new(date: Date.current, status: :degraded)
    assert_equal "Today", day.date_label
    assert_equal "degraded", day.detail
  end

  test "a day with no measurement reads as no data" do
    assert_equal "no data", day_with.detail
  end

  test "aria label combines the date and detail" do
    day = day_with(uptime_fraction: 1.0)
    assert_equal "#{day.date_label}: 100.00% uptime", day.aria_label
  end

  private
    def day_with(**attributes)
      Upright::Service::DailyStatus.new(date: Date.new(2026, 6, 15), **attributes)
    end
end
