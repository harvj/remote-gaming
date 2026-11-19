module Query
  class Users < Query::Base
    def game_stats
      User.find_by_sql(
        [ <<~SQL,
          select users.id, username, games.key, games.name,
              COALESCE((select count(players.id) from players join game_sessions on game_sessions.id = players.game_session_id where game_sessions.experimental = FALSE and players.game_id = games.id and users.id = user_id group by user_id), 0) as play_count
          from users
          left outer join games on 1=1
          where users.id = ?
        SQL
        params[:user_id] ]
      )
    end
  end
end
