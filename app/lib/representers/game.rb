module Representers
  class Game < Representers::Base
    def build_object(game)
      @game = game
      scalar = {
        name: game.name,
        key: game.key,
        uri: game_path(game.key),
        groupCardsBy: game.play_class::CONFIG[:groupCardsBy],
        sortCardsBy: game.play_class::CONFIG[:sortCardsBy]
      }
      return scalar if scalar_only?

      scalar.merge(
        sessions: Representers::GameSessionRow.(game_sessions)
      )
    end

    attr_reader :game

    def game_sessions
      ::GameSession.find_by_sql(<<~SQL
        SELECT games.key AS game_key,
          game_sessions.id,
          game_sessions.uid,
          game_sessions.started_at,
          game_sessions.completed_at,
          game_sessions.state,
          (SELECT count(*) FROM players WHERE players.game_session_id = game_sessions.id) AS player_count,
          winner.name AS winner_name,
          winner.role AS winner_role
        FROM games
        JOIN game_sessions ON game_sessions.game_id = games.id
        LEFT OUTER JOIN (
          SELECT players.game_session_id,
            users.name AS name,
            roles.name AS role FROM players
          JOIN users ON users.id = players.user_id
          JOIN roles ON roles.id = players.role_id
          WHERE players.winner = true
          ) AS winner ON winner.game_session_id = game_sessions.id
        WHERE games.id = #{game.id}
        ORDER BY game_sessions.id DESC
      SQL
      )
    end
  end
end
