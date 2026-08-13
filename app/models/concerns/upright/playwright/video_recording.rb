module Upright::Playwright::VideoRecording
  extend ActiveSupport::Concern

  VIDEO_SIZE = { width: 1280, height: 720 }

  included do
    attr_accessor :video_artifacts, :pending_video_recording

    set_callback :page_ready, :after, :capture_video_reference
    set_callback :page_close, :after, :finalize_video
  end

  private
    def video_dir
      Upright.configuration.video_storage_dir
    end

    def finalize_video
      save_video
    end

    def video_recording_options
      if record_video?
        FileUtils.mkdir_p(video_dir)
        { record_video_dir: video_dir.to_s, record_video_size: VIDEO_SIZE }
      else
        {}
      end
    end

    def record_video?
      !Rails.env.test?
    end

    def capture_video_reference
      return unless record_video?
      return unless (video = page.video)

      self.pending_video_recording = { label: current_recording_label, video: video }
    end

    def save_video
      return unless pending_video_recording

      video_path = video_dir.join("#{SecureRandom.hex}.webm").to_s
      pending_video_recording.fetch(:video).save_as(video_path)

      self.video_artifacts ||= []
      video_artifacts << pending_video_recording.merge(path: video_path)
    ensure
      delete_source_video
      self.pending_video_recording = nil
    end

    # Playwright writes its own source file per page; delete it after saving
    # our copy so page@*.webm recordings don't accumulate on disk.
    def delete_source_video
      pending_video_recording&.fetch(:video)&.delete
    rescue => error
      Rails.error.report(error)
    end

    def attach_video(probe_result)
      Array(video_artifacts).each do |artifact|
        next unless File.exist?(artifact.fetch(:path))

        File.open(artifact.fetch(:path), "rb") do |file|
          Upright::Artifact.new(name: recording_artifact_filename(artifact[:label], "webm"), content: file).attach_to(probe_result, timestamped: true)
        end

        FileUtils.rm(artifact.fetch(:path))
      end

      if logger.respond_to?(:struct)
        video_artifact = probe_result.artifacts.find { |attached| attached.content_type == "video/webm" }
        if video_artifact
          # Log the blob key, never a signed URL: signed URLs in logs/OTEL are
          # bearer credentials for the recording.
          logger.struct probe_artifact_key: video_artifact.key
        end
      end

      self.video_artifacts = []
    end

    def recording_artifact_filename(label, extension)
      [ recording_artifact_basename(label), extension ].join(".")
    end

    def recording_artifact_basename(label)
      [ artifact_recording_name, label ].compact.join(" ")
    end

    def artifact_recording_name
      respond_to?(:probe_name) ? probe_name : service_name.to_s
    end

    def current_recording_label
      nil
    end
end
