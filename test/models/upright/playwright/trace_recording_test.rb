require "test_helper"

class Upright::Playwright::TraceRecordingTest < ActiveSupport::TestCase
  class TraceHost
    include ActiveSupport::Callbacks
    define_callbacks :page_ready, :page_close
    include Upright::Playwright::TraceRecording

    attr_accessor :context
  end

  test "starts tracing without DOM snapshots" do
    tracing = mock("tracing")
    tracing.expects(:start).with(screenshots: true, snapshots: false)

    host = TraceHost.new
    host.context = stub(tracing: tracing)

    host.send(:start_trace)
  end
end
