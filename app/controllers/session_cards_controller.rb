class SessionCardsController < ApplicationController
  before_action :authenticate_user!

  def update
    card = SessionCard.where(game_session_id: scoped_sessions.select(:id)).find(params[:id])
    raise ActiveRecord::RecordNotFound if card.session.digital_modern_art || card.session.historical_modern_art?

    SessionFrame::Record.call(card.session, action: "play_card") do
      card.reload
      raise ActiveRecord::RecordNotFound unless card.player&.user == current_user && card.player.removed_at.nil?
      raise SessionFrame::Record::InvalidAction, "Invalid card action" unless params[:card_action] == "play"

      card.play
    end
    render_session(card.session)
  end
end
