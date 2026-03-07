class Play::Pandemic < Play::Base
  PLAY_SEQUENCE = [].freeze

  TERMS = {
    name: 'name',
    nameSort: 'name',
    value: 'strain',
    valueSort: 'strain',
    dealtDuringState: 'dealt',
    status: 'status'
  }

  CONFIG = {
    groupCardsBy: 'value',
    sortCardsBy: 'status'
  }

  EPIDEMIC_COUNT = 5

  INIT_DEAL_COUNTS = { '2' => 4, '3' => 3, '4' => 2 }.freeze

  INFECTION_DEAL_COUNTS = { '0' => 2, '1' => 2, '2' => 2, '3' => 3, '4' => 3, '5' => 4, '6' => 4 }.freeze

  PLAYER_ACTIONS = {
    inactive: %w(trade),
    draw: %w(trade draw),
    infect: %w(infect),
    trade: %w(cancel submit_trade),
    discard: %w()
  }

  attr_accessor :init_draw_pile

  def initial_deal_count
    INIT_DEAL_COUNTS[players.count.to_s]
  end

  # --- Player actions

  def possible_player_actions(player)
    return [] if resilient_pop?
    actions = PLAYER_ACTIONS[player.action_phase.to_sym]
    actions = actions.reject { |action| action == 'infect' } if forecast?
    actions
  end

  def player_draw(player)
    2.times do
      if card = deck_cards('draw').first
        card.deal(player)
      else
        transition_state and break
      end
    end
    player.update_attribute(:action_phase, 'infect')

    if epidemic?
      session.cards.by_card_key('epidemic').active.last&.discard(player)
      reset_forecast if forecast?
      if !session.completed?
        new_city = decks.find_by(key: 'infection').cards.shuffle.first
        new_city.deal
        new_city.update_attribute(:session_deck, decks.find_by(key: "infection-#{epidemic_count - 1}"))
      end
    end
    check_hand_limit(player)
  end

  def player_infect(player)
    if epidemic?
      infected.update_all(dealt_at: nil)
      decks.create(key: "infection-#{epidemic_count}")
    end
    if one_quiet_night?
      session.update_attribute(:special_game_phase, nil)
    else
      infect_next(infection_count)
    end
    session.advance_turn
  end

  def player_trade(player)
    player.update_attributes(
      action_phase_revert: player.action_phase,
      action_phase: 'trade',
    )
  end

  def player_submit_trade(player, params)
    card = player.cards.find(params['card']['id'])
    receiving_player = session.players.find(params['player']['id'])
    if card.present? && receiving_player.present?
      card.update_attribute(:player, receiving_player)
      check_hand_limit(receiving_player)
    end
    player.update_attribute(:action_phase, player.action_phase_revert)
  end

  def player_cancel(player)
    player.update_attribute(:action_phase, player.action_phase_revert)
  end

  def player_start_turn(player)
    player.update_attribute(:action_phase, 'draw')
  end

  # --- Card actions

  def card_played(session_card)
    card = session_card.card
    case card.name
    when 'resilient pop', 'one quiet night', 'forecast'
      session.update_attribute(:special_game_phase, card.name)
    end
    if forecast?
      forecast_deck = decks.create(key: 'forecast')
      cards = deck_cards('infection').first(6)
      cards.each { |card| card.update_attribute(:session_deck, forecast_deck) }
    end
    check_hand_limit(session_card.player)
  end

  def card_discarded(session_card)
    if resilient_pop?
      session.update_attribute(:special_game_phase, nil)
    else
      check_hand_limit(session_card.player)
    end
  end

  def card_dealt(session_card)
    if session_card.card.key == 'infection'
      session_card.update_attribute(:session_deck, decks.find_by(key: "infection-#{epidemic_count}"))
      if forecast?
        session.update_attribute(:special_game_phase_timer, session.special_game_phase_timer + 1)
        if forecast_deck.empty?
          reset_forecast
        elsif session.special_game_phase_timer == infection_count
          session.advance_turn
        end
      end
    end
  end

  # --- Card attributes

  def card_playable?(session_card)
    card = session_card.card
    return false if resilient_pop?
    return false if current_player.action_phase == 'infect' && card.value != 'special'
    card.key === 'player'
  end

  def card_playable_out_of_turn?(session_card)
    card = session_card.card
    card.value == 'special'
  end

  def card_discardable?(session_card)
    card = session_card.card
    player = session_card.player

    return true if card.key == 'epidemic'
    return card.key == 'infection' if resilient_pop?
    return false if player.nil?
    return card.key == 'player' && card.value != 'special' if player.action_phase == 'discard'
    false
  end

  def card_tradeable?(session_card)
    card = session_card.card
    card.key == 'player' && card.value != 'special'
  end

  def card_valid_action(session_card)
    return 'deal' if forecast? && session_card.session_deck.key == 'forecast' && session.current_player.action_phase == 'infect'
    nil
  end

  # --- General game functions

  def build_card_decks
    create_infection_decks
    deal_initial_cards
    create_draw_decks
  end

  # --- Game specific functions

  def infection_count
    INFECTION_DEAL_COUNTS[epidemic_count.to_s]
  end

  def check_hand_limit(player)
    if player.action_phase == 'discard'
      player.update_attribute(:action_phase, player.action_phase_revert) if player.cards.active.count <= 7
    elsif player.cards.active.count > 7
      player.update_attributes(
        action_phase_revert: player.action_phase,
        action_phase: 'discard'
      )
    end
  end

  def infect_next(count=1)
    count.times do
      infecting_city = deck_cards('infection').first
      infecting_city.deal
      infecting_city.update_attribute(:session_deck, decks.find_by(key: "infection-#{epidemic_count}"))
    end
  end

  def reset_forecast
    if forecast_deck.empty?
      infect_next(infection_count - session.special_game_phase_timer) if infection_count > session.special_game_phase_timer
    else
      fake_forecast_placement = decks.create(key: "infection-#{epidemic_count - 1}-forecast")
      forecast_deck.each { |card| card.update_attribute(:session_deck, fake_forecast_placement) }
    end
    session.update_attributes(special_game_phase: nil, special_game_phase_timer: 0)
    session.advance_turn
  end

  def create_infection_decks
    infection = decks.create(key: 'infection')
    game.cards.where(key: 'infection').each do |card|
      SessionCard::Create.!(infection, card: card)
    end

    infection_discard = decks.create(key: 'infection-0')
    infection.cards.shuffle.first(9).each do |card|
      card.update_attribute(:session_deck, infection_discard)
      card.deal
    end
  end

  def deal_initial_cards
    deck = decks.create(key: 'initial')
    dealt_cards = init_draw_pile.shift(players.count * initial_deal_count)
    dealt_cards.each do |card|
      SessionCard::Create.!(deck, card: card)
    end
    deck.deal_cards(players, initial_deal_count)
  end

  def create_draw_decks
    EPIDEMIC_COUNT.times do |i|
      deck = decks.create(key: "draw-#{i}")
      SessionCard::Create.!(deck, card: game.cards.find_by(name: "epidemic"))
    end
    init_draw_pile.each_with_index do |card, index|
      deck_number = index % EPIDEMIC_COUNT
      SessionCard::Create.!(decks.find_by(key: "draw-#{deck_number}"), card: card)
    end
  end

  # --- Session attributes

  def display_card_groups
    result = []

    if forecast_deck.any?
      result << { name: 'forecast', cards: forecast_deck }
    end
    result << { name: 'infections', count: infected.count, cards: infected }
    result << { name: 'draw deck', count: deck_cards('draw').count, cards: [] }

    if res_pop = session.cards.by_card_key('infection').discarded.first
      result << { name: 'resilient population', cards: [res_pop] }
    end

    result
  end

  def show_inactive_cards?
    epidemic? && %w(infect discard).include?(current_player.action_phase)
  end

  def allow_display_player_switching?
    true
  end

  def prompt_for_player_score?
    false
  end

  # --- Queries

  def init_draw_pile
    @init_draw_pile ||= game.cards.where(key: 'player').shuffle
  end

  def infected
    session.cards.by_card_key('infection').active.order('dealt_at DESC')
  end

  def forecast_deck
    session.cards.by_deck_key('forecast')
  end

  def deck_cards(key)
    SessionCard.find_by_sql(<<~SQL
      select session_cards.* from session_cards
      inner join session_decks on session_decks.id = session_cards.session_deck_id
      where session_cards.game_session_id = #{session.id}
      and session_decks.key like '#{key}%'
      and dealt_at is null
      and discarded_at is null
      order by session_decks.key DESC, random()
    SQL
    )
  end

  def epidemic_count
    SessionFrame.find_by_sql(<<~SQL
      select count(*) from session_frames
      inner join session_cards on subject_id = session_cards.id
      inner join cards on session_cards.card_id = cards.id
      where session_frames.game_session_id = #{session.id}
      and subject_type = 'SessionCard'
      and action = 'card_dealt'
      and cards.name = 'epidemic'
    SQL
    ).first.count
  end

  def epidemic?
    SessionFrame.find_by_sql(<<~SQL
      select * from session_frames
      inner join session_cards on subject_id = session_cards.id
      inner join cards on session_cards.card_id = cards.id
      where session_frames.game_session_id = #{session.id}
      and key <> 'infection'
      and action = 'card_dealt'
      order by session_frames.id DESC
      limit 2
    SQL
    ).select { |c| c.name == 'epidemic' }.present?
  end

  # --- Game special phases

  def special_game_phase?
    resilient_pop? || one_quiet_night? || forecast?
  end

  def resilient_pop?
    session.special_game_phase == 'resilient pop'
  end

  def one_quiet_night?
    session.special_game_phase == 'one quiet night'
  end

  def forecast?
    session.special_game_phase == 'forecast'
  end

  # --- Action prompts

  def special_game_phase_prompt
    return unless special_game_phase?
    return if forecast? && current_player.action_phase != 'infect'
    prompts = {
      forecast: "Infect #{infection_count}... Choose from the Forecast group to infect...",
      one_quiet_night: "One quiet night... Next infection will not deal cards...",
      resilient_pop: "Resilient population... Choose an infected city to discard..."
    }
    prompts[session.special_game_phase.tr(' ','_').to_sym]
  end

  def player_action_prompts(action_phase)
    prompts = {
      draw: "Your turn. Choose cards to play or draw 2...",
      trade: "Trading... Click a card and a player to trade it to...",
      discard: "Hand limit reached... click cards to discard or play specials...",
      infect: "Your turn to infect #{infection_count}..."
    }
    prompts[action_phase.to_sym]
  end
end
