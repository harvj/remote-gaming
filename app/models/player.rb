class Player < ApplicationRecord
  belongs_to :user
  belongs_to :session, class_name: "GameSession", foreign_key: "game_session_id"
  belongs_to :next_player, class_name: "Player", optional: true
  belongs_to :role, optional: true

  has_many :cards, class_name: "SessionCard"
  has_many :frames, class_name: "SessionFrame", foreign_key: "acting_player_id"

  validates :user_id, uniqueness: { scope: :game_session_id }
  validates :action_phase, presence: true

  validate :session_not_in_progress, on: :create
  validate :session_not_full, on: :create

  scope :joined, -> { where(removed_at: nil) }
  scope :removed, -> { where.not(removed_at: nil) }

  after_commit :broadcast_session

  def play(action: nil, params: {})
    Player.transaction do
      SessionFrame::Create.(session,
        action: "player_#{action}",
        acting_player: self,
        subject: self
      )
      session.engine.player_action(self, action: action, params: params)
    end
  end

  def leave_session
    update!(removed_at: Time.current)
    SessionFrame::Create.(session,
      action: "player_left",
      acting_player: self,
      subject: self
    )
  end

  def start_turn
    session.engine.player_start_turn(self)
  end

  def end_turn
    session.engine.player_end_turn(self)
  end

  def action_prompt
    session.engine.player_action_prompt(self)
  end

  def possible_actions
    return [] if session.completed?
    session.engine.possible_player_actions(self)
  end

  def can_pass?
    session.engine.can_pass?(self)
  end

  def idle?
    action_phase == "idle"
  end

  private

  def broadcast_session
    GameSession::Broadcast.(session)
  end

  def session_not_in_progress
    errors.add(:session, "in progress") if session.started?
  end

  def session_not_full
    errors.add(:session, "has maximum number of players") if session.full?
  end
end
