class PlayersController < ApplicationController
  before_action :authenticate_user!
  before_action :load_player, only: %i[play update]

  def create
    session = scoped_sessions.find_by!(uid: params[:uid])
    raise ActiveRecord::RecordNotFound unless session.can_view?(current_user)

    raise ActiveRecord::RecordNotFound if session.digital_modern_art

    SessionFrame::Record.call(session, action: "join") do
      if (player = session.all_players.find_by(user: current_user))
        player.rejoin_session if player.removed_at
      else
        Player::Create.!(current_user, session: session)
      end
    end
    render_session(session)
  end

  def update
    case params[:player_action]
    when "leave_session"
      raise SessionFrame::Record::InvalidAction, "Experiment seats stay with the table" if @player.session.experimental?

      @player.leave_session
    when nil
      score = Integer(params.require(:player).fetch(:score).to_s, 10, exception: false)
      raise SessionFrame::Record::InvalidAction, "Enter a whole-number score" unless score&.between?(-2_147_483_648, 2_147_483_647)

      Player::Update.!(@player, score: score)
    else
      raise SessionFrame::Record::InvalidAction, "Invalid player action"
    end
    render_session(@player.session)
  end

  def play
    @player.play(action: params[:player_action].to_s)
    render_session(@player.session)
  end

  private

  def load_player
    @player = Player.joined.where(game_session_id: scoped_sessions.select(:id)).find_by!(id: params[:id], user: current_user)
    raise ActiveRecord::RecordNotFound if @player.session.digital_modern_art
  end
end
