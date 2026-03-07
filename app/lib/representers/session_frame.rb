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

      result.merge!(
        subject: Representers::SessionCard.(frame.subject)
      ) if frame.subject_type == "SessionCard"

      result
    end
  end
end
