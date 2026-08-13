class Upright::SessionsController < Upright::ApplicationController
  skip_before_action :authenticate_user, only: [ :new, :create ]
  # External identity providers (OpenID Connect, including
  # `response_mode=form_post`) return to the callback without a Rails authenticity
  # token and are validated by the provider's own state nonce, so Rails' automatic
  # token check is skipped here. The static_credentials callback is same-origin and
  # MUST present a token — enforced explicitly in verify_credential_callback.
  skip_forgery_protection only: :create

  before_action :ensure_not_signed_in, only: [ :new, :create ]
  before_action :verify_credential_callback, only: :create

  def new
  end

  def create
    reset_session
    user = Upright::User.from_omniauth(request.env["omniauth.auth"])
    session[:user_info] = { email: user.email, name: user.name }
    redirect_to upright.root_path
  end

  def destroy
    reset_session
    redirect_to upright.root_path(subdomain: Upright.configuration.global_subdomain), allow_other_host: true
  end

  private
    def ensure_not_signed_in
      redirect_to upright.site_root_path if session[:user_info].present?
    end

    # The static_credentials callback must arrive as a POST carrying a valid
    # authenticity token: any other verb (a Lax-cookie GET, or a HEAD that CSRF
    # skips) or a missing/foreign token could otherwise plant an attacker-chosen
    # session (CVE-2026-67993). External providers are validated by their own
    # state nonce (see skip_forgery_protection above) and are exempt.
    def verify_credential_callback
      return unless params[:provider].to_s == "static_credentials"

      if !request.post?
        head :not_found
      elsif !verified_request?
        raise ActionController::InvalidAuthenticityToken
      end
    end

    def upright
      Upright::Engine.routes.url_helpers
    end
end
