class Play::Base
  include ServiceObject

  def initialize(game_session=nil, active_user=nil)
    @session     = game_session || create_session!
    @active_user = active_user
  end

  attr_reader :session, :active_user

  delegate :game, :players, :decks, :next_action, :frames, :current_player,
    to: :session

  def call
    Game.transaction { transition_state if session.playable? }
    Services::Response.new(subject: session, errors: errors)
  end

  def create_session!
    game = Game.find_by(key: self.class.name.demodulize.underscore)
    GameSession::Create.!(game).subject
  end

  def active_player
    return unless active_user.present?
    @active_player ||= players.find_by(user_id: active_user.id)
  end

  def started
    session.update_attribute(:started_at, Time.zone.now)
    build_card_decks
    set_turn_order
  end

  def completed
    session.update_attribute(:completed_at, Time.zone.now)
  end

  def transition_state
    action = next_action
    session.update_attribute(:state, action)
    SessionFrame::Create.(session,
      action: action,
      acting_player: active_player,
      subject: session
    )
    send(action)
  end

  def last_card_played
    last_session_card_played&.card
  end

  def last_session_card_played
    last_card_played_frame&.subject
  end

  def last_card_played_frame
    session.frames.where(subject_type: 'SessionCard', action: 'card_played', state: session.state).last
  end

  # --- Player actions

  def player_action(player, action: nil, params: {})
    return if !player.possible_actions.include?(action)
    if params.present?
      send("player_#{action}", player, params)
    else
      send("player_#{action}", player)
    end
  end

  def player_start_turn(player)
    player.update_attribute(:action_phase, 'active')
  end

  def player_end_turn(player)
    player.update_attribute(:action_phase, 'inactive')
  end

  # --- Player attributes

  def player_action_prompt(player)
    return unless session.started? && session.current_player
    return "#{session.current_player.user.name}'s turn..." if player.inactive?
    return special_game_phase_prompt if special_game_phase_prompt.present?
    player_action_prompts(player.action_phase)
  end

  # --- Card actions

  def card_played(_session_card)
  end

  def card_discarded(_session_card)
  end

  def card_dealt(_session_card)
  end

  # --- Card attributes

  def card_playable?(_session_card)
    false
  end

  def card_playable_out_of_turn?(_session_card)
    false
  end

  def card_discardable?(_session_card)
    false
  end

  def card_tradeable?(_session_card)
    false
  end

  def card_valid_action(_session_card)
    nil
  end

  # --- General game functions

  def assign_role(_user)
    session.available_roles.shuffle.first
  end

  def build_card_decks
  end

  def set_turn_order
    randomized_players = players.shuffle
    first_player = randomized_players[0]

    randomized_players.each_with_index do |player, index|
      player.update_attributes!(
        turn_order: index + 1,
        next_player: randomized_players[index + 1] || first_player
      )
    end
    first_player.start_turn
    session.update_attribute(:current_player, first_player)
  end

  def special_game_phase?
    false
  end

  def special_game_phase_prompt
  end

  # --- Session attributes

  def display_card_groups
    []
  end

  def allow_display_player_switching?
    false
  end

  def show_inactive_cards?
    false
  end

  def prompt_for_player_score?
    true
  end
end
