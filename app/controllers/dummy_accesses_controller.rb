class DummyAccessesController < ApplicationController
  layout "dummy_access"

  before_action :require_experiments
  before_action :authenticate_user!, only: %i[create rotate revoke]
  before_action :load_experiment, only: %i[create rotate revoke]
  before_action :private_response

  def new
  end

  def redeem
    return head :forbidden if current_user && !current_user.dummy?

    access, ticket = DummyAccess.redeem!(params[:dummy_credential])
    reset_session
    session[:dummy_browser] = ticket
    redirect_to game_session_path(access.session.uid), status: :see_other
  end

  def create
    SessionFrame::Record.call(@experiment, action: "dummy_added") do
      raise SessionFrame::Record::InvalidAction, "Seats can only be added before the game starts" unless @experiment.joinable?

      handle = SecureRandom.hex(12)
      user = User.create!(name: "Dummy #{@experiment.all_players.count + 1} (#{handle.first(6)})",
        username: "dummy_#{handle}", dummy: true)
      player = Player::Create.!(user, session: @experiment, recorded_by: owner_player).subject
      @credential = player.create_dummy_access!(expires_at: Time.current).issue!
    end
    render :issued, status: :created
  end

  def rotate
    @credential = access_for_seat.issue!
    render :issued
  end

  def revoke
    access_for_seat.revoke!
    redirect_to game_session_path(@experiment.uid), status: :see_other
  end

  def logout
    if (access = dummy_access)
      access.with_lock { access.revoke! if DummyAccess.authorized(session[:dummy_browser]) }
    end
    reset_session
    redirect_to dummy_login_path, status: :see_other
  end

  private

  def require_experiments
    head :not_found unless ExperimentalAccess.enabled?
  end

  def load_experiment
    raise ActiveRecord::RecordNotFound unless current_user && !current_user.dummy?

    @experiment = scoped_sessions.where(experimental: true, experiment_owner: current_user).find_by!(uid: params[:uid])
  end

  def access_for_seat
    @experiment.all_players.find(params[:player_id]).dummy_access || raise(ActiveRecord::RecordNotFound)
  end

  def owner_player
    @experiment.players.find_by!(user: current_user)
  end

  def private_response
    response.headers["Cache-Control"] = "no-store"
    # Browsers send a null Origin for a form POST under no-referrer.
    response.headers["Referrer-Policy"] = action_name == "new" ? "same-origin" : "no-referrer"
  end
end
