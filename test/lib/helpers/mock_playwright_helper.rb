module MockPlaywrightHelper
  class MockBrowser
    def new_context(**options)
      MockContext.new(options[:storageState])
    end
  end

  class MockContext
    attr_reader :state, :init_script

    def initialize(state = nil)
      @state = state
      @closed = false
      @init_script = nil
    end

    def add_init_script(script: nil, path: nil)
      @init_script = script if script
    end

    def new_page = MockPage.new
    def storage_state = { "cookies" => [ { "name" => "session", "value" => "fresh" } ] }
    def close = @closed = true
    def closed? = @closed
  end

  class MockPage
    def goto(url, **options) = nil
    def url = "https://example.com/"
    def close = nil
    def on(event, callback) = nil
    def wait_for_load_state(state: nil) = nil
    def evaluate(script) = 0
  end
end
