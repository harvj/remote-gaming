module Representers
  class SessionFrame < Representers::Base
    def build_object(frame)
      result = {
        id: frame.id,
        action: frame.action&.titleize,
        actingPlayer: Representers::Player.(frame.acting_player, scalar: true),
        affectedPlayer: Representers::Player.(frame.affected_player, scalar: true),
        state: frame.state&.titleize
      }

      if frame.subject_type == "SessionCard"
        card = frame.payload&.dig("card")
        result[:subject] = if card
          { name: card["name"].titleize, value: card["value"].titleize }
        else
          Representers::SessionCard.(frame.subject) if frame.subject
        end
      end

      result
    end
  end
end
