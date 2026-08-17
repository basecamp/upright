# Playwright source recordings are deleted right after they're saved as
# artifacts, but a crashed run can still strand them. Sweep any video files
# old enough that no probe run could still be using them.
class Upright::PlaywrightVideoSweepJob < Upright::ApplicationJob
  queue_as :default

  MAX_AGE = 1.hour

  def perform
    stray_videos.each do |path|
      File.delete(path) if File.mtime(path) < MAX_AGE.ago
    rescue Errno::ENOENT
      # Already gone
    end
  end

  private
    def stray_videos
      Dir.glob(Upright.configuration.video_storage_dir.join("*.webm").to_s)
    end
end
