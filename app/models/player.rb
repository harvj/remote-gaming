class Player < ApplicationRecord
  belongs_to :user
  belongs_to :session, class_name: 'GameSession', foreign_key: 'game_session_id'
  belongs_to :next_player, class_name: 'Player', optional: true
  belongs_to :role, optional: true

  has_many :cards, class_name: 'SessionCard'
  has_many :frames, class_name: 'SessionFrame', foreign_key: 'acting_player_id'

  validates :user_id, uniqueness: { scope: :game_session_id }
  validates :action_phase, presence: true

  validate :session_not_in_progress, on: :create
  validate :session_not_full, on: :create

  def play(action: nil, params: {})
    Player.transaction do
      SessionFrame::Create.(session,
        action: "player_#{action}",
        acting_player: self,
        subject: self
      )
      session.game_play.player_action(self, action: action, params: params)
    end
  end

  def start_turn
    session.game_play.player_start_turn(self)
  end

  def end_turn
    session.game_play.player_end_turn(self)
  end

  def action_prompt
    session.game_play.player_action_prompt(self)
  end

  def possible_actions
    return [] if session.completed?
    session.game_play.possible_player_actions(self)
  end

  def can_pass?
    session.game_play.can_pass?(self)
  end

  def inactive?
    action_phase == 'inactive'
  end

  private

  def session_not_in_progress
    errors.add(:session, "in progress") if session.started?
  end

  def session_not_full
    errors.add(:session, "has maximum number of players") if session.full?
  end
end
