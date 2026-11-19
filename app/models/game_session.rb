class GameSession < ApplicationRecord
  BEGIN_STATES = %w[waiting started]
  END_STATES   = %w[completed]

  belongs_to :game
  belongs_to :experiment_owner, class_name: "User", optional: true
  belongs_to :current_player, class_name: "Player", optional: true

  has_many :players, -> { joined.order(:turn_order) }
  has_many :all_players, class_name: "Player", dependent: :destroy
  has_one :winner, -> { where(winner: true) }, class_name: "Player"

  has_many :decks, class_name: "SessionDeck", dependent: :destroy
  has_many :cards, class_name: "SessionCard", dependent: :destroy
  has_many :frames, class_name: "SessionFrame", dependent: :restrict_with_exception

  validates :uid, presence: true, uniqueness: true
  validates :state, presence: true
  validate { errors.add(:experiment_owner, "must be a real profile") if experiment_owner&.dummy? }

  scope :ordinary, -> { where(experimental: false) }
  scope :completed, -> { where("completed_at IS NOT NULL") }
  scope :active, -> { where("completed_at IS NULL and state <> ?", "waiting") }
  scope :incomplete, -> { where("completed_at IS NULL") }

  def self.generate_uid
    Passphrase::Passphrase.new(
      number_of_words: 3,
      languages: %w[english]
    ).passphrase.tr(" ", "-")
  end

  delegate :play_class, :min_players, :max_players,
    to: :game

  def engine
    play_class.new(self)
  end

  def play_sequence
    BEGIN_STATES + play_class::PLAY_SEQUENCE + END_STATES
  end

  def player_actions
    Hash.new { |h, k| h[k] = [] }.merge(play_class::PLAYER_ACTIONS)
  end

  def transition_frames
    frames.engine_events.where(subject: self, action: play_sequence).order(:id)
  end

  def transition_actions
    transition_frames.pluck(:action)
  end

  # --- Scopes

  def available_roles
    return game.roles if players.all? { |player| player.role.nil? }
    Role.find_by_sql(<<~SQL
      SELECT * FROM roles
      WHERE game_id = #{game_id}
      AND roles.id NOT IN (
          SELECT DISTINCT role_id FROM players
          WHERE game_session_id = #{id})
    SQL
    )
  end

  def played_card_counts_by_state(state_name)
    SessionCard.find_by_sql([ <<~SQL, id, state_name ])
        SELECT count(*), cards.name FROM session_cards
        INNER JOIN session_frames ON session_frames.subject_id = session_cards.id AND session_frames.subject_type = 'SessionCard'
        INNER JOIN cards ON cards.id = session_cards.card_id
        WHERE session_cards.game_session_id = ?
        AND session_frames."action" = 'card_played'
        AND session_frames."state" = ?
        GROUP BY cards.name
    SQL
  end

  def started?
    started_at.present?
  end

  def completed?
    completed_at.present?
  end

  def next_action
    index = play_sequence.index(state)
    play_sequence[index + 1] if index
  end

  def next_action_prompts
    prompts = {}
    play_class::PLAY_SEQUENCE.each { |i| prompts[i] = "Play #{i.titleize}" }
    prompts.merge(
      "started" => "Start with #{players.count} players",
      "completed" => "Finish Game"
    )
  end

  def next_action_prompt
    next_action_prompts[next_action]
  end

  def advance_turn
    SessionFrame::Record.require_command!(self)
    previous_player = current_player
    previous_player.end_turn
    update!(current_player: previous_player.next_player)
    current_player.start_turn
    SessionFrame::Create.!(self, action: "turn_advanced", subject: self,
      acting_player: previous_player, affected_player: current_player)
  end

  def display_state
    if waiting?
      playable? ? "Ready to begin": "Waiting for players"
    else
      state.titleize
    end
  end

  def waiting?
    state == "waiting"
  end

  def full?
    players.count >= max_players
  end

  def joinable?
    !full? && !started?
  end

  def playable?
    players.count >= min_players && !completed?
  end

  def active?
    !waiting? && !completed?
  end

  # --- Game specific configuration

  def display_card_groups
    engine.display_card_groups
  end

  def allow_display_player_switching?
    completed? || engine.allow_display_player_switching?
  end

  def prompt_for_player_score?
    completed? && engine.prompt_for_player_score?
  end

  def show_inactive_cards?
    completed? || engine.show_inactive_cards?
  end

  def replayable?
    frames.checkpoints.where(sequence: 1, action: "session_created", format_version: 1).exists?
  end

  def can_view?(user)
    return false unless user
    return experimental? && players.exists?(user_id: user.id) if user.dummy?
    return experiment_owner_id == user.id if experimental?

    (players.exists?(user_id: user.id) || (replayable? && waiting?))
  end

  def broadcast_live!
    GameSessionChannel.broadcast_to(self, { event: "session_changed" })
  end
end
