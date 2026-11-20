class AuthController < ApplicationController
  before_action :require_provider
  before_action :private_response

  def start
    provider = CanonicalAuth.new
    attempt = provider.start
    session[:oidc_attempt] = attempt
    redirect_to provider.authorization_url(attempt), allow_other_host: true
  rescue CanonicalAuth::InvalidLogin
    head :service_unavailable
  end

  def signed_out
    render :signed_out
  end

  def callback
    destination = session.delete(:user_return_to)
    identity, assurance = CanonicalAuth.new.authenticate(session.delete(:oidc_attempt), state: params[:state], code: params[:code])
    AuthLogin.authorized(session[:oidc_login])&.destroy!
    login = identity.with_lock do
      raise CanonicalAuth::InvalidLogin if identity.revoked_at?

      AuthLogin.create!(auth_identity: identity, assurance: assurance, expires_at: CanonicalAuth::SESSION_SECONDS.seconds.from_now)
    end
    reset_session
    session[:oidc_login] = login.id
    redirect_to url_from(destination) || root_path
  rescue CanonicalAuth::InvalidLogin
    render plain: "Sign-in could not be verified. Return to the login page to try again.", status: :unauthorized
  end

  private

  def private_response
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  def require_provider
    head :not_found unless CanonicalAuth.enabled?
  end
end
