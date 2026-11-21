class AuthController < ApplicationController
  skip_before_action :load_game
  before_action :private_response

  def start
    saved_destination = session.delete(:user_return_to)
    destination = NavigationLogin.return_path(params[:return_to]) ||
      NavigationLogin.return_path(saved_destination) || NavigationLogin.entry(request.host)
    start_login(destination)
  end

  def start_admin
    return head :not_found unless HistoricalUserAdministration.available_on?(request.host)

    start_login(historical_users_path, historical_admin: true)
  end

  def signed_out
    render :signed_out
  end

  def end_session
    AuthLogin.end_session(session[:oidc_login])
    reset_session
    destination = ModernArtStaging.enabled? ? staging_signed_out_path : root_path
    redirect_to destination, status: :see_other
  end

  def callback
    return head :not_found if Rails.env.production? && request.host != NavigationLogin.canonical_host

    state, code, error = callback_parameters
    attempt = AuthLoginAttempt.consume(state: state, browser: session[:oidc_browser])
    raise CanonicalAuth::InvalidLogin unless attempt && code.present? && !error

    identity, assurance, grant, deadline, username = CanonicalAuth.new.authenticate(attempt.provider_attempt(state), state: state, code: code)
    raise CanonicalAuth::InvalidLogin unless deadline.future?

    admin_only = HistoricalUserAdministration.available_on?(request.host) && !ProductionReplay.enabled?
    if (admin_only || attempt.historical_admin?) && !HistoricalUserAdministration.owner_identity?(identity)
      raise CanonicalAuth::InvalidLogin
    end
    AuthLogin.end_session(session[:oidc_login])
    login = identity.with_lock do
      raise CanonicalAuth::InvalidLogin if identity.revoked_at?

      AuthLogin.create!(auth_identity: identity, assurance: assurance, grant_token: grant, expires_at: deadline)
    end
    reset_session
    session[:oidc_login] = login.id
    session[:oidc_username] = username if username
    redirect_to attempt.destination
  rescue CanonicalAuth::InvalidLogin
    login_failure(:unauthorized)
  end

  private

  def start_login(destination, historical_admin: false)
    accepts_document = request.format.html? || request.headers["Accept"] == "*/*"
    return head :bad_request if !accepts_document || request.headers["Sec-Purpose"].to_s.include?("prefetch") ||
      request.headers["Purpose"] == "prefetch" ||
      request.headers["Sec-Fetch-Dest"].present? && request.headers["Sec-Fetch-Dest"] != "document"

    return login_failure(:service_unavailable) unless CanonicalAuth.enabled?

    if Rails.env.production? && request.host != NavigationLogin.canonical_host
      return redirect_to "https://#{NavigationLogin.canonical_host}#{login_path(return_to: destination)}", allow_other_host: true
    end

    login = AuthLogin.authorized(session[:oidc_login])
    if login && (!historical_admin || HistoricalUserAdministration.owner_identity?(login.auth_identity))
      return redirect_to destination
    end

    provider = CanonicalAuth.new
    attempt = provider.start
    authorization_url = provider.authorization_url(attempt)
    session[:oidc_browser] ||= SecureRandom.urlsafe_base64(32)
    AuthLoginAttempt.record!(attempt, browser: session[:oidc_browser], destination: destination, historical_admin: historical_admin)
    redirect_to authorization_url, allow_other_host: true
  rescue CanonicalAuth::InvalidLogin
    login_failure(:service_unavailable)
  end

  def callback_parameters
    parameters = URI.decode_www_form(request.query_string).group_by(&:first)
    %w[state code error].map do |key|
      entries = parameters.fetch(key, [])
      raise CanonicalAuth::InvalidLogin if entries.size > 1

      entries.first&.last
    end
  rescue ArgumentError
    raise CanonicalAuth::InvalidLogin, cause: nil
  end

  def login_failure(status)
    @title = "Remote Gaming sign-in"
    render :login_failure, layout: "directory", status: status
  end

  def directory_signed_in?
    false
  end
  helper_method :directory_signed_in?

  def private_response
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end
end
