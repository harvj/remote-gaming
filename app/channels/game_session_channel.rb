class GameSessionChannel < ApplicationCable::Channel
  def subscribed
    session = GameSession.find_by(uid: params[:uid])
    return reject unless session&.can_view?(current_user)
    return reject if ModernArtStaging.enabled? && session.game.key != ModernArtStaging::GAME_KEY

    stream_for session, coder: ActiveSupport::JSON do |payload|
      transmit(payload) if session.reload.can_view?(current_user)
    end
  end
end
