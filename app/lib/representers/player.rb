module Representers
  class Player < Representers::Base
    def build_object(player)
      return nil if player.nil?

      scalar = {
        id: player.id,
        actionPhase: player.action_phase,
        actionPrompt: player.action_prompt,
        moderator: player.moderator?,
        role: Representers::Role.(player.role),
        score: player.score,
        turnOrder: player.turn_order,
        user: Representers::User.(player.user),
        winner: player.winner,
        playPath: play_player_path(player),
        playerPath: player_path(player)
      }


      return scalar if scalar_only?

      scalar[:badges] = player.badges if player.respond_to? :badges
      if player.respond_to?(:last_win_date)
        scalar[:lastWinDate] = player.last_win_date&.strftime("%b %e")
        scalar[:lastWinDateClass] = last_win_date_class(player.last_win_date)
      end
      scalar.merge(
        activeCards: Representers::SessionCard.(player.cards.active),
        inactiveCards: Representers::SessionCard.(player.cards.inactive),
        playHistory: Representers::SessionFrame.(player.frames.card_played),
        possibleActions: player.possible_actions,
      )
    end

    private

    def last_win_date_class(date)
      return if date.nil?
      if date > 7.days.ago
        "green1"
      elsif date > 21.days.ago
        "green2"
      elsif date > 35.days.ago
        "yellow1"
      elsif date > 49.days.ago
        "yellow2"
      elsif date > 63.days.ago
        "orange1"
      elsif date > 77.days.ago
        "orange2"
      else
        "red1"
      end
    end
  end
end
