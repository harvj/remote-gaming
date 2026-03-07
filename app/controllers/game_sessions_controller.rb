class GameSessionsController < ApplicationController
  before_action :load_game_session, only: %i(update show destroy)
  before_action :load_game, only: %i(create update destroy)

  def create
    game_session = @game.play_class.().subject
    redirect_to game_session_path(game_session.uid)
  end

  def update
    updated_session = @game.play_class.(@game_session, current_user).subject
    @rep_session = Representers::GameSession.(updated_session, user: current_user)
    render json: { status: 'success', content: { session: @rep_session } }
  end

  def show
    @rep_session = Representers::GameSession.(@game_session, user: current_user)
    respond_to do |format|
      format.html
      format.json { render json: { status: 'success', content: { session: @rep_session } } }
    end
  end

  def destroy
    @game_session.destroy
    redirect_to game_path(@game.key)
  end

  private

  def load_game
    @game = @game_session&.game || Game.find_by(key: params[:game_key])
  end

  def load_game_session
    @game_session = GameSession.find_by(uid: params[:uid]) || not_found
  end
end
