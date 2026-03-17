class GamesController < ApplicationController
  def index
    games = Game.all.order(:name)

    @rep_games = Representers::Game.(games, scalar: true)
    respond_to do |format|
      format.html
      format.json { render json: { status: "success", content: { games: @rep_games } }.to_json }
    end
  end

  def show
    @rep_game = Representers::Game.(@game)
    respond_to do |format|
      format.html
      format.json { render json: { status: "success", content: { game: @rep_game } }.to_json }
    end
  end
end
