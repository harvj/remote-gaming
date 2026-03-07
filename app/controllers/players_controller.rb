class PlayersController < ApplicationController
  before_action :load_player, only: %i(play pass update)
  before_action :load_session, only: %i(create)

  def create
    player_create = Player::Create.!(current_user, session: @session)
    render json: {
      status: player_create.status,
      content: { session: Representers::GameSession.(@session.reload, user: current_user) },
      errors: player_create.errors
    }
  end

  def update
    player_update = Player::Update.(@player, player_params)
    render json: {
      status: player_update.status,
      content: { session: Representers::GameSession.(@player.session, user: current_user) },
      errors: player_update.errors
    }
  end

  def play
    @player.play(action: params[:player_action], params: play_params)
    @rep_session = Representers::GameSession.(@player.session, user: current_user)
    render json: { status: 'success', content: { session: @rep_session }, errors: [] }
  end

  private

  def load_session
    @session = GameSession.find_by(uid: params[:uid])
  end

  def load_player
    @player = Player.find(params[:id])
  end

  def play_params
    params[:player_action].include?('submit') ? params : {}
  end

  def player_params
    params.require(:player).permit(:score)
  end
end
