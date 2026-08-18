require "test_helper"

class Upright::PlaywrightVideoSweepJobTest < ActiveSupport::TestCase
  setup do
    @video_dir = Pathname.new(Dir.mktmpdir)
    Upright.configuration.stubs(:video_storage_dir).returns(@video_dir)
  end

  teardown do
    FileUtils.remove_entry(@video_dir)
  end

  test "deletes stray video files older than the sweep age" do
    stray = @video_dir.join("page@abc123.webm")
    File.binwrite(stray, "stale video")
    File.utime(2.hours.ago.to_time, 2.hours.ago.to_time, stray)

    Upright::PlaywrightVideoSweepJob.perform_now

    assert_not File.exist?(stray)
  end

  test "keeps recent video files" do
    fresh = @video_dir.join("page@def456.webm")
    File.binwrite(fresh, "in-flight video")

    Upright::PlaywrightVideoSweepJob.perform_now

    assert File.exist?(fresh)
  end

  test "ignores non-video files" do
    other = @video_dir.join("notes.txt")
    File.binwrite(other, "keep me")
    File.utime(2.hours.ago.to_time, 2.hours.ago.to_time, other)

    Upright::PlaywrightVideoSweepJob.perform_now

    assert File.exist?(other)
  end
end
