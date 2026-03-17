class PlayersController < ApplicationController
  before_action :load_player, only: %i[play update]
  before_action :load_game_session, only: %i[create]

  VALID_ACTIONS = %w[leave_session].freeze

  def create
    player = @game_session.all_players.find_by(user: current_user)

    if player
      player.update!(removed_at: nil)
    else
      Player::Create.!(current_user, session: @game_session)
    end

    @game_session.reload.broadcast_live!

    render json: {
      status: "success",
      content: { session: Representers::GameSession.(@game_session, viewer: current_user) },
      errors: []
    }
  end

  def update
    action = params[:player_action].to_s

    if action.present?
      unless VALID_ACTIONS.include?(action)
        render json: { status: "error", content: {}, errors: [ "Invalid player action" ] }, status: :unprocessable_entity
        return
      end

      @player.public_send(action)
    else
      Player::Update.(@player, player_params)
    end

    @player.reload.session.broadcast_live!

    @rep_session = Representers::GameSession.(@player.session, viewer: current_user)

    render json: { status: "success", content: { session: @rep_session }, errors: [] }
  end

  def play
    @player.play(action: params[:player_action], params: play_params)

    @player.session.broadcast_live!

    @rep_session = Representers::GameSession.(@player.session, viewer: current_user)
    render json: { status: "success", content: { session: @rep_session }, errors: [] }
  end

  private

  def load_game_session
    @game_session = GameSession.find_by(uid: params[:uid])
  end

  def load_player
    @player = Player.find(params[:id])
  end

  def play_params
    params[:player_action].include?("submit") ? params : {}
  end

  def player_params
    params.require(:player).permit(:score)
  end
end
