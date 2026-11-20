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
        sessions: Representers::GameSessionRow.(game_sessions),
        experiments: ExperimentalAccess.enabled? ? Representers::GameSessionRow.(experiments) : nil
      )
    end

    attr_reader :game

    def experiments
      return [] unless viewer && !viewer.dummy?

      game.sessions.where(experimental: true, experiment_owner: viewer).order(id: :desc)
    end

    def game_sessions
      return [] unless viewer

      ::GameSession.ordinary.where(id: ::Player.joined.where(user_id: viewer.id).select(:game_session_id))
        .where(game: game).order(id: :desc).includes(:game, winner: %i[role user])
    end
  end
end
