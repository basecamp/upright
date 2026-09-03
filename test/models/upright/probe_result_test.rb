require "test_helper"

class Upright::ProbeResultTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  test ".to_chart returns expected structure" do
    result = upright_probe_results(:http_probe_result)
    chart_data = result.to_chart

    assert_equal result.created_at.iso8601, chart_data[:created_at]
    assert_equal result.duration.to_f, chart_data[:duration]
    assert_equal result.status, chart_data[:status]
    assert_equal result.probe_name, chart_data[:probe_name]
  end

  test "error attribute attaches exception report on create" do
    exception = RuntimeError.new("Something went wrong")
    exception.set_backtrace([ "app/models/foo.rb:10", "app/controllers/bar.rb:5" ])

    result = Upright::ProbeResult.create!(
      probe_name: "test", probe_type: :http, probe_target: "https://example.com",
      status: :fail, duration: 1.0, error: exception
    )

    report = result.exception_report

    assert_includes report, "RuntimeError: Something went wrong"
    assert_includes report, "app/models/foo.rb:10"
    assert_includes report, "app/controllers/bar.rb:5"
  end

  test ".cleanup_stale removes old successes but keeps recent failures" do
    stale_success_id = upright_probe_results(:stale_success).id
    fresh_success_id = upright_probe_results(:http_probe_result).id
    stale_failure_id = upright_probe_results(:stale_failure).id
    recent_failure_id = upright_probe_results(:recent_failure).id

    Upright::ProbeResult.cleanup_stale

    assert_not Upright::ProbeResult.exists?(stale_success_id)
    assert Upright::ProbeResult.exists?(fresh_success_id)
    assert_not Upright::ProbeResult.exists?(stale_failure_id)
    assert Upright::ProbeResult.exists?(recent_failure_id)
  end

  test ".cleanup_stale purges attachments and blobs for stale records without enqueuing jobs" do
    stale = upright_probe_results(:stale_success)
    stale_attachment_id = stale.artifacts.first.id
    stale_blob_id = stale.artifacts.first.blob.id

    fresh = upright_probe_results(:http_probe_result)
    fresh_blob_id = fresh.artifacts.first.blob.id

    assert_no_enqueued_jobs do
      Upright::ProbeResult.cleanup_stale
    end

    assert_not ActiveStorage::Attachment.exists?(stale_attachment_id)
    assert_not ActiveStorage::Blob.exists?(stale_blob_id)
    assert ActiveStorage::Blob.exists?(fresh_blob_id)
  end

  test ".cleanup_stale caps failures at retention limit" do
    recent_failure_id = upright_probe_results(:recent_failure).id

    original = Upright.config.failure_retention_limit
    Upright.config.failure_retention_limit = 2
    Upright::ProbeResult.cleanup_stale

    assert_not Upright::ProbeResult.exists?(recent_failure_id)
    assert_equal 2, Upright::ProbeResult.fail.count
  ensure
    Upright.config.failure_retention_limit = original
  end
end
