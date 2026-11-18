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
      return [] unless viewer

      ::GameSession.where(id: ::Player.joined.where(user_id: viewer.id).select(:game_session_id))
        .where(game: game).order(id: :desc).includes(:game, winner: %i[role user])
    end
  end
end
