module Upright::Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user
    helper_method :signed_in?
  end

  private
    def authenticate_user
      if session[:user_info].present?
        Upright::Current.user = Upright::User.new(session[:user_info])
      else
        session[:return_to] = request.url if request.get?
        redirect_to new_admin_session_url(default_url_options.merge(subdomain: Upright.configuration.global_subdomain)), allow_other_host: true
      end
    end

    def signed_in?
      Upright::Current.user.present?
    end
end
