class GamesController < ApplicationController
  before_action :authenticate_user!, only: :show
  def index
    games = Game.all.order(:name)

    @rep_games = Representers::Game.(games, scalar: true)
    respond_to do |format|
      format.html
      format.json { render json: { status: "success", content: { games: @rep_games } }.to_json }
    end
  end

  def show
    @game ||= Game.find_by!(key: params[:game_key])
    @rep_game = Representers::Game.(@game, viewer: current_user)
    respond_to do |format|
      format.html
      format.json { render json: { status: "success", content: { game: @rep_game } }.to_json }
    end
  end
end
