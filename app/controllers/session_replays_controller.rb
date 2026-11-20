class SessionReplaysController < ApplicationController
  layout "directory"
  skip_before_action :load_game
  before_action :authenticate_user!
  before_action :private_response
  helper_method :directory_signed_in?

  def index
    @title = "My replays"
    @replays = GameSession.ordinary.joins(:game).where(games: { key: "modern_art" })
      .where(id: Player.joined.where(user_id: current_user.id).select(:game_session_id))
      .order(created_at: :desc, id: :desc)
  end

  def show
    @title = "Modern Art replay"
    @replay_session = find_replay_session
    frames = @replay_session.frames.order(:sequence).to_a
    SessionFrame::Replay.call(frames)
    cursor = params.key?(:frame) ? Integer(params[:frame].to_s, 10, exception: false) : frames.size
    return head :bad_request unless cursor&.between?(1, frames.size)

    view = SessionFrame::View.new(frames, cursor:)
    @replay = view.for_viewer(current_user)
    @can_branch = !current_user.dummy? && BrowserIdentity.oidc_user(session) == current_user &&
      SessionFrame::Branch.allowed?(@replay_session, current_user)
    @replay[:branchable] = @can_branch && SessionFrame::Branch.supported?(view, current_user)
    @lineage = replay_lineage
    respond_to do |format|
      format.html
      format.json { render json: @replay }
    end
  rescue SessionFrame::Replay::Unavailable
    respond_to do |format|
      format.html { render :unavailable }
      format.json { render json: { error: "Deterministic replay is unavailable for this history." }, status: :unprocessable_entity }
    end
  end

  private

  def replay_lineage
    return unless @replay_session.parent_session_id

    origin = @replay_session.parent_session
    fork = @replay_session.fork_frame.sequence
    lineage = { fork: fork, rulesVersion: @replay_session.branch_rules_version }
    return lineage unless origin.can_replay?(current_user)

    lineage.merge(path: session_replay_path(origin.uid, frame: fork))
  end

  def find_replay_session
    scope = ProductionReplay.enabled? ? GameSession.ordinary : GameSession.all
    table = scope.find_by!(uid: params[:uid])
    raise ActiveRecord::RecordNotFound unless table.can_replay?(current_user)

    table
  end

  def private_response
    response.headers["Cache-Control"] = "no-store"
  end

  def directory_signed_in?
    current_user.present? && !current_user.dummy?
  end
end
