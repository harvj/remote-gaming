class HistoricalUsersController < ApplicationController
  layout "directory"
  skip_before_action :load_game
  before_action :private_response, :require_owner
  before_action :load_profile, except: :index
  helper_method :directory_signed_in?

  def index
    @title = "Historical users"
    @profiles = HistoricalUserAdministration.profiles.includes(:auth_identity, :historical_user_claim).order(:id)
    @associations = Player.joins(session: :game).merge(GameSession.ordinary)
      .where(user_id: @profiles.map(&:id)).group("players.user_id", "games.name").count
      .group_by { |(id, _game), _count| id }
  end

  def show
    @title = "Historical profile #{@profile.id}"
    @claim = @profile.historical_user_claim
    @identity = @profile.auth_identity
    @decisions = @identity ? AuthIdentityDecision.where(auth_identity: @identity).order(:created_at, :id) : []
  end

  def update
    HistoricalUserClaim.save_proposal!(@profile, owner: @owner, email: params.expect(:proposed_email),
      revision: params.expect(:revision))
    redirect_to historical_user_path(@profile.id), status: :see_other
  rescue ActiveRecord::RecordInvalid
    show
    @form_error = "Enter a valid email address."
    render :show, status: :unprocessable_content
  rescue HistoricalUserClaim::Unavailable
    proposal_changed
  end

  def prepare
    return head :bad_request unless params[:confirm] == "1"

    HistoricalUserClaim.prepare!(@profile, owner: @owner, revision: params.expect(:revision))
    redirect_to historical_user_path(@profile.id), status: :see_other
  rescue HistoricalUserClaim::Unavailable
    proposal_changed
  end

  private

  def proposal_changed
    show
    @form_error = "This claim changed or is no longer editable. Review the current profile before continuing."
    render :show, status: :conflict
  end

  def load_profile
    @profile = HistoricalUserAdministration.profiles.find(params[:id])
  end

  def require_owner
    @owner = HistoricalUserAdministration.owner(session, request.host)
    head :not_found unless @owner
  end

  def private_response
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "same-origin"
  end

  def directory_signed_in?
    @owner.present?
  end
end
