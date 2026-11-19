class AuthController < ApplicationController
  before_action :require_provider

  def start
    provider = CanonicalAuth.new
    attempt = provider.start
    session[:oidc_attempt] = attempt
    redirect_to provider.authorization_url(attempt), allow_other_host: true
  rescue CanonicalAuth::InvalidLogin
    head :service_unavailable
  end

  def callback
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    destination = session.delete(:user_return_to)
    identity, assurance = CanonicalAuth.new.authenticate(session.delete(:oidc_attempt), state: params[:state], code: params[:code])
    AuthLogin.authorized(session[:oidc_login])&.destroy!
    login = AuthLogin.create!(auth_identity: identity, assurance: assurance, expires_at: CanonicalAuth::SESSION_SECONDS.seconds.from_now)
    reset_session
    session[:oidc_login] = login.id
    redirect_to url_from(destination) || root_path
  rescue CanonicalAuth::InvalidLogin
    render plain: "Sign-in could not be verified. Return to the login page to try again.", status: :unauthorized
  end

  private

  def require_provider
    head :not_found unless CanonicalAuth.enabled?
  end
end
