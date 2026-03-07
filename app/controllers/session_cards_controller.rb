class SessionCardsController < ApplicationController
  before_action :load_session_card, only: %i(update)

  def update
    @session_card.send(params[:card_action]) if valid_actions.include?(params[:card_action])
    @rep_session = Representers::GameSession.(@session_card.session, user: current_user)
    render json: { status: 'success', content: { session: @rep_session }, errors: [] }
  end

  private

  def valid_actions
    %w(discard play deal)
  end

  def load_session_card
    @session_card = SessionCard.find(params[:id])
  end
end
