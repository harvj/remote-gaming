class SessionBranchesController < ApplicationController
  skip_before_action :load_game
  before_action :authenticate_user!

  def create
    response.headers["Cache-Control"] = "no-store"
    return head :not_found unless ExperimentalAccess.enabled? && BrowserIdentity.oidc_user(session) == current_user

    source = GameSession.find_by!(uid: params[:uid])
    cursor = Integer(params[:frame].to_s, 10, exception: false)
    return head :bad_request unless cursor&.positive?

    branch = SessionFrame::Branch.call(source, viewer: current_user, cursor:)
    redirect_to game_session_path(branch.uid), status: :see_other
  rescue SessionFrame::Branch::Unsupported => error
    render plain: error.message, status: :unprocessable_entity
  end
end
