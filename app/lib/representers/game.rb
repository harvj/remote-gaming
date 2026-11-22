module Representers
  class Game < Representers::Base
    def build_object(game)
      @game = game
      scalar = {
        name: game.name,
        key: game.key,
        uri: (ModernArtStaging.enabled? ? "/" : game_path(game.key)),
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

      visible = ::GameSession.ordinary
      if game.key == "modern_art" && ModernArtPractice.owner?(ModernArtStaging::GAME_HOST, viewer)
        human_tables = ModernArtPracticeTable.where("setup ->> 'mode' = 'human'").select(:uid)
        visible = visible.or(::GameSession.where(experiment_owner: viewer, uid: human_tables))
      end

      visible.where(id: ::Player.joined.where(user_id: viewer.id).select(:game_session_id), game: game)
        .order(id: :desc).includes(:game, winner: %i[role user])
    end
  end
end
