class GameSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_game_session, except: :create

  def create
    game = @game || Game.find_by!(key: params[:game_key])
    experimental = params[:experimental] == "1"
    return head :forbidden if experimental && !(ExperimentalAccess.enabled? && BrowserIdentity.oidc_user(session))
    return head :not_found if experimental && game.key != "modern_art"

    if game.key == "modern_art" && !experimental && ModernArtPractice.enabled_on?(request.host)
      return head :not_found unless ModernArtPractice.owner?(request.host, current_user)
      table = GameSession.transaction do
        game_session = GameSession::Create.!(game, experimental: true, experiment_owner: current_user).subject
        Player::Create.!(current_user, session: game_session)
        ModernArtPracticeTable.open!(current_user, game, human_session: game_session)
        game_session
      end
      return redirect_to game_session_path(table.uid)
    end

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
    return update_digital if @digital_table

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
    if @digital_table
      response.headers["Cache-Control"] = "private, no-store"
      @digital_board = @digital_table.human_view(current_user) unless @digital_table.position.empty?
      return render json: @digital_board if request.format.json? && @digital_board
      return head :conflict if request.format.json?
      return render :show
    end

    if @game_session.historical_modern_art?
      response.headers["Cache-Control"] = "private, no-store"
      representer = Representers::GameSession.new(@game_session, viewer: current_user)
      @historical_board = representer.historical_board
      if request.format.json?
        return render json: { status: "success", content: {
          session: session_view(@game_session).merge(historicalTabletop: @historical_board)
        } }
      end
      return render :historical
    end
    respond_to do |format|
      format.html do
        response.headers["Cache-Control"] = "no-store"
        @rep_session = session_view(@game_session)
      end
      format.json { render_session(@game_session) }
    end
  end

  def observe
    return head :not_found if @digital_table || @game_session.historical_modern_art?

    SessionFrame::Observe.call(@game_session, current_user,
      params.require(:observation).permit(:type, :context_frame_id, :corrects_frame_id, :occurred_at,
        data: {}).to_h)
    render_session(@game_session)
  end

  private

  def update_digital
    response.headers["Cache-Control"] = "private, no-store"
    @game_session.with_lock do
      @digital_table.reload
      if @digital_table.position.empty?
        raise ActiveRecord::RecordNotFound unless current_user.id == @digital_table.owner_id && params[:command] == "start"

        roster = @game_session.players.includes(:user).sort_by { |player| [ player.user_id == @digital_table.owner_id ? 0 : 1, player.id ] }
        @digital_table.begin_human!(roster)
        @game_session.update!(state: "season_one", started_at: Time.current)
      else
        seat = @digital_table.seat_for(current_user)
        raise ActiveRecord::RecordNotFound if seat.nil?

        if current_user.dummy?
          dummy_access.with_lock do
            raise ActiveRecord::RecordNotFound unless DummyAccess.authorized(session[:dummy_browser])

            @digital_table.act!(params[:revision], params[:command], params[:value], seat: seat)
          end
        else
          @digital_table.act!(params[:revision], params[:command], params[:value], seat: seat)
        end
        if @digital_table.position.fetch("phase") == "complete"
          @game_session.update!(state: "completed", completed_at: Time.current)
        else
          season = Play::ModernArt::PLAY_SEQUENCE.fetch(@digital_table.position.fetch("season") - 1)
          @game_session.update!(state: season) if @game_session.state != season
        end
      end
    end
    @game_session.broadcast_live!
    return redirect_to game_session_path(@game_session.uid), status: :see_other if request.format.html?

    render json: @digital_table.human_view(current_user)
  rescue ModernArtPracticeTable::StalePosition
    render json: { message: "The table advanced in another browser.", board: @digital_table.reload.human_view(current_user) }, status: :conflict
  rescue Games::ModernArt::PracticeRules::IllegalCommand
    if @digital_table.reload.position.empty?
      return render plain: "Add at least three seats before starting.", status: :unprocessable_entity
    end

    render json: { message: "That action is unavailable at this table.", board: @digital_table.human_view(current_user) }, status: :unprocessable_entity
  end

  def load_game_session
    @game_session = scoped_sessions.find_by!(uid: params[:uid])
    raise ActiveRecord::RecordNotFound unless @game_session.can_view?(current_user)

    @game = @game_session.game
    @digital_table = @game_session.digital_modern_art
    raise ActiveRecord::RecordNotFound if @digital_table && !ModernArtPractice.enabled_on?(request.host)
  end
end
