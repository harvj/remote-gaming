class Player::Create < Services::Create
  def initialize(user, params)
    @user = user
    @params = params
    assign_role
    super(user, params.merge(
      action_phase: 'inactive',
      game_id: params[:session].game_id
    ))
  end

  attr_reader :user, :role

  def assign_role
    params[:role] = params[:session].game_play.assign_role(user)
  end

  def apply_post_processing
    SessionFrame::Create.(subject.session,
      action: :player_created,
      acting_player: subject,
      subject: subject
    )
  end
end
