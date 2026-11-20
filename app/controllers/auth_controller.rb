class AuthController < ApplicationController
  before_action :require_provider
  before_action :private_response

  def start
    destination = NavigationLogin.return_path(params[:return_to])
    session[:user_return_to] = destination if destination
    start_login
  end

  def start_admin
    return head :not_found unless HistoricalUserAdministration.available_on?(request.host)

    session[:user_return_to] = historical_users_path
    start_login(historical_admin: true)
  end

  def start_login(historical_admin: false)
    provider = CanonicalAuth.new
    attempt = provider.start
    attempt["historical_admin"] = true if historical_admin
    session[:oidc_attempt] = attempt
    redirect_to provider.authorization_url(attempt), allow_other_host: true
  rescue CanonicalAuth::InvalidLogin
    head :service_unavailable
  end

  private :start_login

  def signed_out
    render :signed_out
  end

  def end_session
    AuthLogin.authorized(session[:oidc_login])&.destroy!
    reset_session
    redirect_to root_path, status: :see_other
  end

  def callback
    destination = session.delete(:user_return_to)
    attempt = session.delete(:oidc_attempt)
    identity, assurance = CanonicalAuth.new.authenticate(attempt, state: params[:state], code: params[:code])
    admin_only = HistoricalUserAdministration.available_on?(request.host) && !ProductionReplay.enabled?
    if (admin_only || attempt&.fetch("historical_admin", false)) && !HistoricalUserAdministration.owner_identity?(identity)
      raise CanonicalAuth::InvalidLogin
    end
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
