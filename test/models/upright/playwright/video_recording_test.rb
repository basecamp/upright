require "test_helper"

class Upright::Playwright::VideoRecordingTest < ActiveSupport::TestCase
  class VideoHost
    include ActiveSupport::Callbacks
    define_callbacks :page_ready, :page_close
    include Upright::Playwright::VideoRecording

    attr_accessor :logger

    def probe_name = "video_test"
  end

  setup do
    set_test_site
  end

  test "deletes the source video after saving it" do
    video = mock("video")
    video.expects(:save_as).with(regexp_matches(/\.webm\z/))
    video.expects(:delete)

    host = VideoHost.new
    host.pending_video_recording = { label: nil, video: video }

    host.send(:save_video)

    assert_nil host.pending_video_recording
    assert_equal 1, host.video_artifacts.size
  end

  test "deletes the source video even when saving fails" do
    video = mock("video")
    video.expects(:save_as).raises(RuntimeError, "context closed")
    video.expects(:delete)

    host = VideoHost.new
    host.pending_video_recording = { label: nil, video: video }

    assert_raises(RuntimeError) { host.send(:save_video) }
    assert_nil host.pending_video_recording
  end

  test "logs the blob key, never a signed URL" do
    probe_result = Upright::ProbeResult.create!(probe_type: "playwright", probe_name: "video_test", duration: 1.0, status: "ok")
    video_path = File.join(Dir.mktmpdir, "#{SecureRandom.hex}.webm")
    File.binwrite(video_path, "fake video bytes")

    struct_logs = []
    host = VideoHost.new
    host.video_artifacts = [ { label: nil, path: video_path } ]
    host.logger = Logger.new("/dev/null").tap do |logger|
      logger.define_singleton_method(:struct) { |fields| struct_logs << fields }
    end

    host.send(:attach_video, probe_result)

    assert struct_logs.any?, "Expected a structured log entry for the video artifact"
    logged = struct_logs.flat_map { |fields| fields.values.map(&:to_s) }.join(" ")
    assert_no_match(/rails\/active_storage|https?:/, logged)
  end
end
