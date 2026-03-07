class UsersController < ApplicationController
  before_action :load_user

  def show
    game = Game.find_by(key: 'modern_art')
    @active_sessions = @user.sessions.incomplete
    @game_stats = Query::Users.(:game_stats, user_id: @user.id)
    @score_stats = Query::Players.(:score_stats, game_id: game.id)
    @single_double_stats = Query::Players.(:single_double_stats)
    @turn_order_stats = Query::Players.(:turn_order_stats).group_by(&:player_count)
    @user_stats = Query::Players.(:user_stats, game_id: game.id).group_by(&:player_count)
  end

  private

  def load_user
    @user = User.find_by(username: params[:id]) || not_found
  end
end
