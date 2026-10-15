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
        # Mounted engines such as Mission Control inherit this controller with their own routes
        redirect_to Upright::Engine.routes.url_helpers.new_admin_session_url(subdomain: Upright.configuration.global_subdomain), allow_other_host: true
      end
    end

    def signed_in?
      Upright::Current.user.present?
    end
end
