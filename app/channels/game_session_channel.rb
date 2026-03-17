class GameSessionChannel < ApplicationCable::Channel
  def subscribed
    session = GameSession.find_by!(uid: params[:uid])

    if (player = session.players.find_by(user: current_user))
      stream_for [ session.uid, player.user.username ]
    else
      stream_for [ session.uid, :public ]
    end
  end
end
