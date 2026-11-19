class ApplicationController < ActionController::Base
  protect_from_forgery

  before_action :restrict_dummy_browser
  before_action :load_game

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  rescue_from SessionFrame::Record::InvalidAction, ActiveRecord::RecordInvalid do |error|
    render json: { status: "error", errors: [ error.message ] }, status: :unprocessable_entity
  end

  private

  def current_user
    return super unless CanonicalAuth.enabled?
    return dummy_access&.user if session.key?(:dummy_browser)

    @current_oidc_user ||= BrowserIdentity.oidc_user(session)
  end

  def dummy_access
    return @dummy_access if defined?(@dummy_access)

    @dummy_access = DummyAccess.authorized(session[:dummy_browser])
  end

  def restrict_dummy_browser
    return unless CanonicalAuth.enabled? && session.key?(:dummy_browser)
    return if controller_path == "dummy_accesses" && %w[new redeem logout].include?(action_name)
    return if dummy_access && %w[game_sessions players session_cards].include?(controller_path) &&
      !(controller_path != "session_cards" && action_name == "create")

    head :not_found
  end
  helper_method :current_user

  def authenticate_user!(**options)
    return super unless CanonicalAuth.enabled?
    return if current_user

    if request.get? && request.format.html?
      session[:user_return_to] = request.fullpath
      redirect_to login_path
    else
      head :unauthorized
    end
  end

  def scoped_sessions
    scope = @game ? @game.sessions : GameSession.all
    return scope.where(id: dummy_access.player.game_session_id) if current_user&.dummy?

    scope
  end

  def session_view(session)
    session.with_lock do
      raise ActiveRecord::RecordNotFound unless session.can_view?(current_user)

      Representers::GameSession.(session, viewer: current_user)
    end
  end

  def render_session(session)
    response.headers["Cache-Control"] = "no-store"
    render json: { status: "success", content: { session: session_view(session) } }
  end

  def load_game
    @game = if ModernArtStaging.enabled?
      Game.find_by!(key: ModernArtStaging::GAME_KEY)
    else
      Game.find_by(slug: request.subdomain)
    end
  end
end
