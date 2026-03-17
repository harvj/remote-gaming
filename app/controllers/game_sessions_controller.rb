class GameSessionsController < ApplicationController
  before_action :load_game_session, only: %i[update show destroy]

  def create
    game_session = @game.play_class.().subject
    redirect_to game_root_path(@game)
  end

  def update
    updated_session = @game.play_class.(@game_session, current_user).subject
    updated_session.broadcast_live!

    @rep_session = Representers::GameSession.(updated_session, viewer: current_user)
    render json: { status: "success", content: { session: @rep_session } }
  end

  def show
    @rep_session = Representers::GameSession.(@game_session, viewer: current_user)
    respond_to do |format|
      format.html
      format.json { render json: { status: "success", content: { session: @rep_session } } }
    end
  end

  def destroy
    @game_session.destroy
    head :ok
  end

  private

  def load_game_session
    @game_session = GameSession.find_by!(uid: params[:uid])
  end
end
