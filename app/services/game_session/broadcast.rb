class GameSession::Broadcast
  def self.call(session, user: nil)
    GameSessionChannel.broadcast_to(
      session,
      session: Representers::GameSession.(session, user: user)
    )
  end
end
