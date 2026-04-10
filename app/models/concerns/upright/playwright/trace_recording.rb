module Upright::Playwright::TraceRecording
  extend ActiveSupport::Concern

  included do
    attr_accessor :trace_artifacts

    set_callback :page_ready, :before, :start_trace
    set_callback :page_close, :before, :stop_trace
  end

  private
    def trace_dir
      Upright.configuration.recording_base_dir
    end

    def start_trace
      context.tracing.start(screenshots: true, snapshots: true)
    end

    def stop_trace
      trace_path = trace_dir.join("#{SecureRandom.hex}.zip").to_s
      FileUtils.mkdir_p(trace_dir)
      context.tracing.stop(path: trace_path)

      self.trace_artifacts ||= []
      trace_artifacts << { label: current_recording_label, path: trace_path }
    rescue => error
      Rails.error.report(error)
    end

    def attach_trace(probe_result)
      Array(trace_artifacts).each do |artifact|
        next unless File.exist?(artifact.fetch(:path))

        File.open(artifact.fetch(:path), "rb") do |file|
          Upright::Artifact.new(name: recording_artifact_filename(artifact[:label], "zip"), content: file).attach_to(probe_result, timestamped: true)
        end

        FileUtils.rm(artifact.fetch(:path))
      end

      self.trace_artifacts = []
    end
end
