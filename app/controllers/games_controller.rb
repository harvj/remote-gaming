class GamesController < ApplicationController
  before_action :load_game, only: %i(show)

  def index
    games = Game.all.order(:name)

    @rep_games = Representers::Game.(games, scalar: true)
    respond_to do |format|
      format.html
      format.json { render json: { status: 'success', content: { games: @rep_games }}.to_json }
    end
  end

  def show
    @rep_game = Representers::Game.(@game)
    respond_to do |format|
      format.html
      format.json { render json: { status: 'success', content: { game: @rep_game }}.to_json }
    end
  end

  private

  def load_game
    @game = Game.find_by(key: params[:game_key]) || not_found
  end
end
