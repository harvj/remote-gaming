module Representers
  class GameSessionRow < Representers::Base
    include ActionView::Helpers::AssetTagHelper

    def build_object(session)
      @session = session
      {
        id: session.id,
        active: session.active?,
        archived: session.completed_at.present? && session.completed_at < Date.parse("2021-01-06"),
        completed: session.completed_at.present?,
        completedAt: session.completed_at&.strftime("%a %e %b %Y %k:%M:%S"),
        completedAtDate: session.completed_at&.strftime("%e %b %Y"),
        createdAt: session.created_at.iso8601,
        playerCount: session.player_count,
        started: session.started_at.present?,
        startedAt: session.started_at&.strftime("%a %e %b %Y %k:%M:%S"),
        startedAtDate: session.started_at&.strftime("%e %b %Y"),
        state: session.state,
        uid: session.uid,
        uri: game_session_path(session.uid),
        waiting: session.waiting?,
        winnerImagePath: image_file_path(session.game_key, session.winner_role),
        winnerInitials: initials(session.winner_name)
      }
    end
  end
end
