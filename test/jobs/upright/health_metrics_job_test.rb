require "test_helper"

class Upright::HealthMetricsJobTest < ActiveSupport::TestCase
  test "reports 1 for primary_site on the primary" do
    with_env("SITE_SUBDOMAIN" => "ams") do
      Upright::HealthMetricsJob.perform_now
    end

    assert_equal 1, yabeda_gauge_value(:primary_site)
  end

  test "reports 0 for primary_site elsewhere" do
    with_env("SITE_SUBDOMAIN" => "nyc") do
      Upright::HealthMetricsJob.perform_now
    end

    assert_equal 0, yabeda_gauge_value(:primary_site)
  end

  test "reports the persistent database as up" do
    Upright::HealthMetricsJob.perform_now

    assert_equal 1, yabeda_gauge_value(:persistent_db_up)
  end

  test "leaves the persistent database alone on a probe-only site" do
    Upright::PersistentRecord.expects(:up?).never

    with_env("SITE_SUBDOMAIN" => "nyc") do
      Upright::HealthMetricsJob.perform_now
    end

    assert_nil yabeda_gauge_value(:persistent_db_up)
    assert_nil yabeda_gauge_value(:rollup_last_run_timestamp_seconds)
  end

  test "reports the persistent database from a site that stores metrics without being primary" do
    Upright.stubs(:current_site).returns(Upright::Site.new(code: "sfo", stores_metrics: true))

    Upright::HealthMetricsJob.perform_now

    assert_equal 0, yabeda_gauge_value(:primary_site)
    assert_equal 1, yabeda_gauge_value(:persistent_db_up)
  end

  test "reports the persistent database as down without failing the other metrics" do
    Upright::PersistentRecord.stubs(:up?).returns(false)

    Upright::HealthMetricsJob.perform_now

    assert_equal 0, yabeda_gauge_value(:persistent_db_up)
    assert_equal 1, yabeda_gauge_value(:primary_site)
  end

  test "reports the most recent rollup as the last run" do
    rollup = upright_rollups_probe_rollups(:example_web_may_11)

    Upright::HealthMetricsJob.perform_now

    assert_equal Upright::Rollups::ProbeRollup.maximum(:created_at).to_i,
      yabeda_gauge_value(:rollup_last_run_timestamp_seconds)
    assert_operator yabeda_gauge_value(:rollup_last_run_timestamp_seconds), :>=, rollup.created_at.to_i
  end

  test "leaves the last run unset when nothing has been rolled up" do
    Upright::Rollups::ProbeRollup.delete_all

    Upright::HealthMetricsJob.perform_now

    assert_nil yabeda_gauge_value(:rollup_last_run_timestamp_seconds)
  end
end
