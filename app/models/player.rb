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

  def play(action: nil, params: {})
    SessionFrame::Record.call(session, action: "player_action") do
      reload
      session.engine.player_action(self, action: action, params: params)
    end
  end

  def leave_session
    change_membership("player_left") do
      raise SessionFrame::Record::InvalidAction, "Cannot leave after play starts" if removed_at || session.started?

      was_captain = table_captain?
      update!(removed_at: Time.current, table_captain: false)
      session.players.reorder(:id).first&.update!(table_captain: true) if was_captain
    end
  end

  def rejoin_session
    change_membership("player_rejoined") do
      unless removed_at && session.joinable?
        raise SessionFrame::Record::InvalidAction, "Cannot rejoin this session"
      end
      update!(removed_at: nil, table_captain: !session.players.exists?(table_captain: true))
    end
  end

  def start_turn
    SessionFrame::Record.require_command!(session)
    session.engine.player_start_turn(self)
  end

  def end_turn
    SessionFrame::Record.require_command!(session)
    session.engine.player_end_turn(self)
  end

  def action_prompt
    session.engine.player_action_prompt(self)
  end

  def possible_actions
    return [] if removed_at || !session.started? || session.completed?
    session.engine.possible_player_actions(self)
  end

  def can_pass?
    session.engine.can_pass?(self)
  end

  def idle?
    action_phase == "idle"
  end

  private

  def change_membership(action)
    SessionFrame::Record.call(session, action: action) do
      reload
      yield
      SessionFrame::Create.!(session, action: action, acting_player: self, subject: self)
    end
  end

  def session_not_in_progress
    errors.add(:session, "in progress") if session.started?
  end

  def session_not_full
    errors.add(:session, "has maximum number of players") if session.full?
  end
end
