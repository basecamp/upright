require "test_helper"

class Upright::Playwright::VideoRecordingTest < ActiveSupport::TestCase
  class FakeVideo
    attr_reader :source_path

    def initialize(source_path)
      @source_path = source_path
      File.write(source_path, "video")
    end

    def save_as(path) = FileUtils.cp(source_path, path)
    def delete = FileUtils.rm_f(source_path)
  end

  class TestProbe < Upright::Probes::Playwright::Base
    def check = true
  end

  setup do
    @video_dir = Pathname.new(Dir.mktmpdir)
    Upright.configuration.video_storage_dir = @video_dir

    @video = FakeVideo.new(@video_dir.join("page@abc123.webm").to_s)
    @probe = TestProbe.new
    @probe.pending_video_recording = { label: nil, video: @video }
  end

  teardown do
    Upright.configuration.video_storage_dir = nil
    FileUtils.remove_entry(@video_dir)
  end

  test "deletes the Playwright source video once the copy is saved" do
    @probe.send(:save_video)

    assert_not File.exist?(@video.source_path)
    assert File.exist?(@probe.video_artifacts.first.fetch(:path))
  end

  test "deletes the Playwright source video when saving the copy raises" do
    @video.stubs(:save_as).raises(RuntimeError, "stream closed")

    assert_raises(RuntimeError) { @probe.send(:save_video) }

    assert_not File.exist?(@video.source_path)
  end

  test "reports a failed delete instead of raising" do
    @video.stubs(:delete).raises(RuntimeError, "channel closed")
    Rails.error.expects(:report).once

    @probe.send(:save_video)

    assert_equal 1, @probe.video_artifacts.size
  end
end
