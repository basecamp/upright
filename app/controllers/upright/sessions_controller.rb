class Upright::SessionsController < Upright::ApplicationController
  skip_before_action :authenticate_user, only: [ :new, :create ]
  skip_forgery_protection only: :create

  before_action :ensure_not_signed_in, only: [ :new, :create ]

  def new
  end

  def create
    return_to = session[:return_to]
    reset_session
    user = Upright::User.from_omniauth(request.env["omniauth.auth"])
    session[:user_info] = { email: user.email, name: user.name }
    redirect_to return_to || upright.root_path, allow_other_host: true
  end

  def destroy
    reset_session
    redirect_to upright.root_path(subdomain: Upright.configuration.global_subdomain), allow_other_host: true
  end

  private
    def ensure_not_signed_in
      redirect_to upright.site_root_path if session[:user_info].present?
    end

    def upright
      Upright::Engine.routes.url_helpers
    end
end
