module Upright::ProxyAuthentication
  extend ActiveSupport::Concern

  private
    def authenticate_user
      if request.authorization.present?
        authenticate_proxy_token
      else
        super
      end
    end

    def authenticate_proxy_token
      authenticate_or_request_with_http_token do |token|
        ActiveSupport::SecurityUtils.secure_compare(token, Upright.configuration.proxy_token.to_s)
      end
    end
end
