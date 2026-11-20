class GameSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_game_session, except: :create

  def create
    game = @game || Game.find_by!(key: params[:game_key])
    experimental = params[:experimental] == "1"
    return head :forbidden if experimental && !(ExperimentalAccess.enabled? && BrowserIdentity.oidc_user(session))
    return head :not_found if experimental && game.key != "modern_art"

    if experimental
      table = GameSession.transaction do
        table = GameSession::Create.!(game, experimental: true, experiment_owner: current_user).subject
        Player::Create.!(current_user, session: table)
        table
      end
    else
      table = GameSession::Create.!(game).subject
    end
    redirect_to game_session_path(table.uid)
  end

  def update
    SessionFrame::Record.call(@game_session, action: "advance_phase") do
      captain = @game_session.players.find_by!(user: current_user, table_captain: true)
      unless captain && @game_session.waiting? && @game_session.playable?
        raise SessionFrame::Record::InvalidAction, "The captain can start when enough players join"
      end
      @game_session.play_class.(@game_session, current_user)
    end
    render_session(@game_session)
  end

  def show
    respond_to do |format|
      format.html do
        response.headers["Cache-Control"] = "no-store"
        @rep_session = session_view(@game_session)
      end
      format.json { render_session(@game_session) }
    end
  end

  def observe
    SessionFrame::Observe.call(@game_session, current_user,
      params.require(:observation).permit(:type, :context_frame_id, :corrects_frame_id, :occurred_at,
        data: {}).to_h)
    render_session(@game_session)
  end

  private

  def load_game_session
    @game_session = scoped_sessions.find_by!(uid: params[:uid])
    raise ActiveRecord::RecordNotFound unless @game_session.can_view?(current_user)

    @game = @game_session.game
  end
end
