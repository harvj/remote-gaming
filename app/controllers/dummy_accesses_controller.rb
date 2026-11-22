class DummyAccessesController < ApplicationController
  layout "dummy_access"

  before_action :require_experiments
  before_action :authenticate_user!, only: %i[create rotate revoke]
  before_action :load_human_table, only: %i[create rotate revoke]
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
    SessionFrame::Record.call(@human_session, action: "dummy_added") do
      raise SessionFrame::Record::InvalidAction, "Seats can only be added before the game starts" unless @human_session.joinable?

      handle = SecureRandom.hex(12)
      name = params[:seat_name].to_s.strip.first(60).presence || "Guest #{@human_session.all_players.count}"
      user = User.create!(name: name,
        username: "dummy_#{handle}", dummy: true)
      player = Player::Create.!(user, session: @human_session, recorded_by: owner_player).subject
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
    redirect_to game_session_path(@human_session.uid), status: :see_other
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

  def load_human_table
    raise ActiveRecord::RecordNotFound unless ModernArtPractice.owner?(request.host, current_user)

    @human_session = scoped_sessions.where(experimental: true, experiment_owner: current_user).find_by!(uid: params[:uid])
    raise ActiveRecord::RecordNotFound unless @human_session.digital_modern_art
  end

  def access_for_seat
    @human_session.all_players.find(params[:player_id]).dummy_access || raise(ActiveRecord::RecordNotFound)
  end

  def owner_player
    @human_session.players.find_by!(user: current_user)
  end

  def private_response
    response.headers["Cache-Control"] = "no-store"
    # Browsers send a null Origin for a form POST under no-referrer.
    response.headers["Referrer-Policy"] = action_name == "new" ? "same-origin" : "no-referrer"
  end
end
