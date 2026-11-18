class Player::Create < Services::Create
  def initialize(user, params)
    @session = params.fetch(:session)
    super(user, params.merge(action_phase: "idle", game_id: @session.game_id))
  end

  def apply_pre_processing
    subject.role = @session.engine.assign_role(subject.user)
    subject.table_captain = !@session.players.exists?(table_captain: true)
  end

  def apply_post_processing
    SessionFrame::Create.!(@session, action: "player_created", acting_player: subject, subject: subject)
  end

  private

  def create(&block)
    SessionFrame::Record.call(@session, action: "join") { super(&block) }
  end
end
