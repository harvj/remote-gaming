class GameSessionChannel < ApplicationCable::Channel
  def subscribed
    session = GameSession.find_by(uid: params[:uid])
    return reject unless session && allowed_at_table?(session)
    return reject if ModernArtStaging.enabled? && session.game.key != ModernArtStaging::GAME_KEY

    stream_for session, coder: ActiveSupport::JSON do |payload|
      transmit(payload) if allowed_at_table?(session.reload)
    end
  end
  private

  def allowed_at_table?(session)
    CanonicalAuth.enabled? ? connection.allowed_at_table?(session) : session.can_view?(current_user)
  end
end
