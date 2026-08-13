class Upright::SessionsController < Upright::ApplicationController
  skip_before_action :authenticate_user, only: [ :new, :create ]

  before_action :ensure_not_signed_in, only: [ :new, :create ]
  before_action :require_post_for_credential_callback, only: :create

  def new
  end

  def create
    return_to = safe_return_to(session[:return_to])
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

    # The credential (static_credentials) callback must arrive as a POST so it
    # passes through Rails' authenticity-token check: any other verb (a Lax-cookie
    # GET, or a HEAD that CSRF also skips) could otherwise plant an attacker-chosen
    # session (CVE-2026-67993). External identity providers (e.g. OpenID Connect)
    # legitimately redirect back via GET and are validated by OmniAuth's own state
    # nonce before we reach here, so they are exempt.
    def require_post_for_credential_callback
      if !request.post? && params[:provider].to_s == "static_credentials"
        head :not_found
      end
    end

    # `allow_other_host: true` is needed to return across our own subdomains
    # (app → a site), so bound it: only honour a stored return_to whose host is
    # this deployment's hostname or a subdomain of it, never a foreign host (F-15).
    def safe_return_to(url)
      return nil if url.blank?

      host = URI.parse(url).host
      hostname = Upright.configuration.hostname
      url if host && hostname.present? && (host == hostname || host.end_with?(".#{hostname}"))
    rescue URI::InvalidURIError
      nil
    end

    def upright
      Upright::Engine.routes.url_helpers
    end
end
