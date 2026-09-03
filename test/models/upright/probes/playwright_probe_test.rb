require "test_helper"

class Upright::Probes::PlaywrightProbeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class StaggeredPlaywrightProbe < Upright::Probes::Playwright::Base
    stagger_by_site 2.minutes

    def check
      true
    end
  end

  test "check_and_record_later enqueues job with stagger delay" do
    with_env("SITE_SUBDOMAIN" => "sfo") do
      assert_enqueued_with job: Upright::ProbeCheckJob, args: [ "Upright::Probes::PlaywrightProbeTest::StaggeredPlaywrightProbe" ] do
        StaggeredPlaywrightProbe.check_and_record_later
      end

      # Verify the job was enqueued with the correct delay
      # sfo is index 2, stagger_by_site is 2.minutes, so delay is 4.minutes
      job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
      assert_in_delta 4.minutes.from_now.to_f, job[:at], 5
    end
  end

  test "check_and_record_later enqueues job with zero delay for first site" do
    with_env("SITE_SUBDOMAIN" => "ams") do
      assert_enqueued_with job: Upright::ProbeCheckJob, args: [ "Upright::Probes::PlaywrightProbeTest::StaggeredPlaywrightProbe" ] do
        StaggeredPlaywrightProbe.check_and_record_later
      end

      # ams is index 0, so no delay
      job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
      assert_in_delta Time.current.to_f, job[:at], 1
    end
  end

  class TestPlaywrightProbe < Upright::Probes::Playwright::Base
    def check
      page.goto("https://example.com")
      wait_for_network_idle
      page.get_by_text("Example Domain").visible?
    end
  end

  test "running a Playwright probe" do
    with_env("SITE_SUBDOMAIN" => "ams") do
      probe = TestPlaywrightProbe.new

      result = probe.perform_check

      assert result
    end
  end

  class FailingPlaywrightProbe < Upright::Probes::Playwright::Base
    def probe_name = "failing_probe"
    def record_video? = true

    def check
      page.goto("https://example.com")
      page.locator("text=This element does not exist").wait_for(timeout: 1000)
      true
    end
  end

  test "failing Playwright probe captures video artifact" do
    with_env("SITE_SUBDOMAIN" => "ams") do
      probe = FailingPlaywrightProbe.new
      probe.check_and_record

      probe_result = Upright::ProbeResult.last
      assert_equal "fail", probe_result.status
      assert_equal "playwright", probe_result.probe_type
      assert_equal "failing_probe", probe_result.probe_name
      assert probe_result.artifacts.attached?, "Expected artifacts to be attached"

      video_artifact = probe_result.artifacts.find { |a| a.content_type == "video/webm" }
      assert video_artifact, "Expected video artifact to be attached"
    end
  end

  test "Playwright probe captures log artifact with HTTP responses" do
    with_env("SITE_SUBDOMAIN" => "ams") do
      probe = TestPlaywrightProbe.new
      probe.check_and_record

      probe_result = Upright::ProbeResult.last
      log_artifact = probe_result.artifacts.find { |a| a.filename.to_s.end_with?(".log") }

      assert log_artifact, "Expected log artifact to be attached"
      assert_equal "text/x-log", log_artifact.content_type
      assert_match(/^\d{14}_ams_test_playwright\.log$/, log_artifact.filename.to_s)

      log_content = log_artifact.download
      assert_match(/200 DOCUMENT/, log_content)
    end
  end
end
