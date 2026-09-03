require "playwright"

class Upright::Probes::Playwright::Base
  include ActiveSupport::Callbacks
  include Upright::Probeable

  define_callbacks :perform_check

  include Upright::Playwright::Lifecycle
  include Upright::Playwright::FormAuthentication
  include Upright::Playwright::Logging
  include Upright::Playwright::OtelTracing
  include Upright::Playwright::VideoRecording
  include Upright::Playwright::TraceRecording
  include Upright::Playwright::Helpers

  set_callback :perform_check, :after, :wait_for_network_idle

  def self.check
    new.perform_check
  end

  def self.check_and_record_later
    Upright::ProbeCheckJob.set(wait: stagger_delay).perform_later(name)
  end

  def perform_check
    with_browser do |browser|
      with_context(browser, **video_recording_options) do
        run_callbacks :perform_check do
          check
        end
      end
    end
  end

  def check
    raise NotImplementedError
  end

  def on_check_recorded(probe_result)
    attach_video(probe_result)
    attach_trace(probe_result)
    attach_log(probe_result)
  end

  def probe_type = "playwright"
  def probe_target = nil
  def probe_service = authentication_service&.to_s
end
