class ApplicationController < ActionController::Base
  protect_from_forgery

  before_action :load_game

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  rescue_from SessionFrame::Record::InvalidAction, ActiveRecord::RecordInvalid do |error|
    render json: { status: "error", errors: [ error.message ] }, status: :unprocessable_entity
  end

  private

  def scoped_sessions
    @game ? @game.sessions : GameSession.all
  end

  def session_view(session)
    session.with_lock do
      raise ActiveRecord::RecordNotFound unless session.can_view?(current_user)

      Representers::GameSession.(session, viewer: current_user)
    end
  end

  def render_session(session)
    response.headers["Cache-Control"] = "no-store"
    render json: { status: "success", content: { session: session_view(session) } }
  end

  def load_game
    @game = Game.find_by(slug: request.subdomain)
  end
end
