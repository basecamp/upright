module Upright::Playwright::FormAuthentication
  extend ActiveSupport::Concern

  included do
    class_attribute :authentication_service
    set_callback :page_ready, :after, :ensure_authenticated
  end

  class_methods do
    def authenticate_with_form(service)
      self.authentication_service = service
    end
  end

  private
    def ensure_authenticated
      if authentication_service
        authenticator_for(authentication_service).new.ensure_authenticated(context, page)
      end
    end

    def authenticator_for(service)
      "::Playwright::Authenticator::#{service.to_s.camelize}".constantize
    end
end
