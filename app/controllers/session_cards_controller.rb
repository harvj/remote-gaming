class SessionCardsController < ApplicationController
  before_action :load_session_card, only: %i[update]

  VALID_ACTIONS = %w[discard play deal].freeze

  def update
    action = params[:card_action].to_s

    unless VALID_ACTIONS.include?(action)
      render json: { status: "error", content: {}, errors: [ "Invalid card action" ] }, status: :unprocessable_entity
      return
    end

    @session_card.public_send(action)
    @rep_session = Representers::GameSession.(@session_card.session, user: current_user)

    render json: { status: "success", content: { session: @rep_session }, errors: [] }
  end

  private

  def load_session_card
    @session_card = SessionCard.find(params[:id])
  end
end
