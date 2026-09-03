class Upright::Playwright::Authenticator::Base
  include Upright::Playwright::Helpers

  attr_reader :page

  def self.authenticate_on(page)
    new.authenticate_on(page)
  end

  def initialize
    @storage_state = Upright::Playwright::StorageState.new(service_name)
  end

  def ensure_authenticated(context, page)
    @page = page
    load_cached_storage_state(context)
    page.goto(auth_check_url, timeout: 10.seconds.in_ms)

    unless session_valid_on?(page)
      authenticate_on(page)
      @storage_state.save(context.storage_state)
    end
  end

  def authenticate_on(page)
    @page = page
    setup_page_logging(page)
    authenticate
    self
  end

  def session_valid?
    wait_for_network_idle(page)

    if page.url == signin_redirect_url
      true
    else
      page.goto(signin_redirect_url, timeout: 10.seconds.in_ms)
      !page.url.include?(signin_path)
    end
  end

  def session_valid_on?(page)
    wait_for_network_idle(page)
    !page.url.include?(signin_path)
  end

  protected

  def signin_redirect_url
    raise NotImplementedError
  end

  def signin_path
    raise NotImplementedError
  end

  def service_name
    raise NotImplementedError
  end

  private
    def auth_check_url
      signin_redirect_url
    end

    def authenticate
      raise NotImplementedError
    end

    def load_cached_storage_state(context)
      if (cached_state = @storage_state.load)
        cached_state.fetch("cookies", []).each do |cookie|
          context.add_cookies([ cookie ])
        end
      end
    end

    def setup_page_logging(page)
      if defined?(RailsStructuredLogging::Recorder)
        RailsStructuredLogging::Recorder.instance.messages.tap do |messages|
          page.on("response", ->(response) {
            next if skip_logging?(response)
            RailsStructuredLogging::Recorder.instance.sharing(messages)
            log_response(response)
          })
        end
      else
        page.on("response", ->(response) {
          next if skip_logging?(response)
          log_response(response)
        })
      end
    end

    def log_response(response)
      headers = response.headers.slice("x-request-id", "x-runtime").compact
      Rails.logger.info "#{response.status} #{response.request.resource_type.upcase} #{response.url} #{headers.to_query}"
    end

    def skip_logging?(response)
      %w[image asset avatar].any? { |pattern| response.url.include?(pattern) }
    end

    def credentials
      Rails.application.credentials
    end
end
