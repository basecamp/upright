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
      if ENV["LOCAL_PLAYWRIGHT"]
        ::Playwright.create(playwright_cli_executable_path: "./node_modules/.bin/playwright") do |playwright|
          playwright.chromium.launch(headless: false, &block)
        end
      else
        server_url = Upright.configuration.playwright_server_url ||
                     Rails.application.config_for(:playwright).fetch(:server_url)
        ::Playwright.connect_to_browser_server(server_url, &block)
      end
    end

    def with_context(browser, **options, &block)
      self.context = create_context(browser, **options)
      context.add_init_script(script: inp_observer_script)
      self.page = context.new_page
      run_callbacks :page_ready
      yield
    ensure
      # Rescue each step independently so a failed close doesn't prevent video capture
      page&.close rescue Rails.error.report($!)
      context&.close rescue Rails.error.report($!)
      run_callbacks :page_close
    end

    def create_context(browser, **options)
      authenticated_context(browser, options) || browser.new_context(userAgent: user_agent, **options)
    end

    def inp_observer_script
      @inp_observer_script ||= File.read(
        Upright::Engine.root.join("lib", "upright", "playwright", "inp_observer.js")
      )
    end
end
