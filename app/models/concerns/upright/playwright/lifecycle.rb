module Upright::Playwright::Lifecycle
  extend ActiveSupport::Concern

  DEFAULT_USER_AGENT = "Upright/1.0 Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

  included do
    attr_accessor :context, :page

    define_callbacks :page_ready
    define_callbacks :page_close
  end

  def user_agent
    Upright.configuration.user_agent.presence || DEFAULT_USER_AGENT
  end

  private
    def with_browser(&block)
      ::Playwright.create(playwright_cli_executable_path: Upright.configuration.playwright_cli_path) do |playwright|
        playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") != "false", &block)
      end
    end

    def with_context(browser, **options, &block)
      self.context = create_context(browser, **options)
      self.page = context.new_page
      run_callbacks :page_ready
      yield
    ensure
      run_callbacks :page_close do
        # Rescue each step independently so one failed close does not block artifact capture
        page&.close rescue Rails.error.report($!)
        context&.close rescue Rails.error.report($!)
      end
    end

    def create_context(browser, **options)
      browser.new_context(userAgent: user_agent, **options)
    end
end
