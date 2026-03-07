class Play::ModernArt < Play::Base
  PLAY_SEQUENCE = %w(season_one season_two season_three season_four).freeze

  DECKS = [
    lite_metal:  { once_around: 3, fixed: 2, sealed: 2, open: 3, double: 2 },
    yoko:        { once_around: 2, fixed: 3, sealed: 3, open: 3, double: 2 },
    cristin_p:   { once_around: 3, fixed: 3, sealed: 3, open: 3, double: 2 },
    karl_gitter: { once_around: 3, fixed: 3, sealed: 3, open: 3, double: 3 },
    krypto:      { once_around: 3, fixed: 3, sealed: 3, open: 4, double: 3 }
  ]

  CARDS_TO_DEAL = {
    season_one:   { '3' => 10, '4' => 9, '5' => 8 },
    season_two:   { '3' => 6,  '4' => 4, '5' => 3 },
    season_three: { '3' => 6,  '4' => 4, '5' => 3 }
  }

  TERMS = {
    name: 'artist',
    nameSort: 'artist',
    value: 'auction type',
    valueSort: 'auction type',
    dealtDuringState: 'season dealt',
    status: 'hand'
  }

  CONFIG = {
    groupCardsBy: 'name',
    sortCardsBy: 'status'
  }

  def deck
    @deck ||= session.decks.find_by(key: 'default')
  end

  def started
    super
    transition_state
  end

  # --- State transitions

  def season_one
    deck.deal_cards(session.players, CARDS_TO_DEAL[:season_one][session.players.count.to_s])
  end

  def season_two
    deck.deal_cards(session.players, CARDS_TO_DEAL[:season_two][session.players.count.to_s])
  end

  def season_three
    deck.deal_cards(session.players, CARDS_TO_DEAL[:season_three][session.players.count.to_s])
  end

  def season_four
  end

  # --- Player actions

  def possible_player_actions(player)
    return ['pass'] if can_pass?(player) && player == current_player
    []
  end

  def player_pass(player)
    single_double_player = last_card_played_frame.acting_player
    session.advance_turn
    if single_double_player == player.next_player
      SessionFrame::Create.(session,
        action: 'free_single_double',
        affected_player: single_double_player,
        subject: last_session_card_played
      )
      session.advance_turn
    end
  end

  # --- Card actions

  def card_played(session_card)
    card = session_card.card
    if session.played_card_counts_by_state(session.state).any? { |i| i.count >= 5 }
      transition_state
      session.advance_turn
    elsif card.value != 'double'
      session.advance_turn
    end
  end

  # --- Card attributes

  def card_playable?(session_card)
    card = session_card.card
    return true if last_card_played_frame.blank?
    last_card_played.value != 'double' || (card.name == last_card_played.name && card.value != 'double') || session.frames.last.action == 'free_single_double'
  end

  # --- General game functions

  def build_card_decks
    DECKS.each do |params|
      deck = session.decks.create!(key: 'default')
      params.each do |name, value_counts|
        value_counts.each do |value, count|
          count.times do
            SessionCard::Create.!(deck, card: session.game.cards.find_by(name: name, value: value))
          end
        end
      end
    end
  end

  def assign_role(user)
    return game.roles.find_by(name: 'tokyo') if %w(jim radio).include?(user.username)
    return game.roles.find_by(name: 'bilbao') if user.username == 'robert'
    return game.roles.find_by(name: 'new york') if user.username == 'paul'
    return game.roles.find_by(name: 'berlin') if user.username == 'bob'
    return game.roles.find_by(name: 'paris') if user.username == 'mark'
    super
  end

  # --- Game specific functions

  def can_pass?(player)
    return false if player.inactive?
    return false if last_card_played_frame.blank?
    return false if session.frames.last&.action == 'free_single_double'
    last_card_played.value == 'double' && session.frames.where(action: 'player_passed', acting_player: player).where('created_at > ?', last_card_played_frame.created_at).blank?
  end

  # --- Action prompts

  def player_action_prompts(action_phase)
    prompts = {
      active: "Your turn...",
    }
    prompts[action_phase.to_sym]
  end
end
