module MockPlaywrightHelper
  class MockBrowser
    def new_context(**options)
      MockContext.new(options[:storageState])
    end
  end

  class MockContext
    attr_reader :state, :tracing

    def initialize(state = nil)
      @state = state
      @tracing = MockTracing.new
      @closed = false
    end

    def new_page = MockPage.new
    def storage_state = { "cookies" => [ { "name" => "session", "value" => "fresh" } ] }
    def close = @closed = true
    def closed? = @closed
  end

  class MockTracing
    def start(**options) = nil

    def stop(path:)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "trace")
    end
  end

  class MockVideo
    def save_as(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "video")
    end
  end

  class MockPage
    def goto(url, **options) = nil
    def url = "https://example.com/"
    def close = nil
    def on(event, callback) = nil
    def video = MockVideo.new
    def wait_for_load_state(**options) = nil
  end
end
