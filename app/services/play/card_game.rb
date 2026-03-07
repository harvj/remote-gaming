class Play::CardGame < Play::Base
  PLAY_SEQUENCE = %w(round_one round_two)
  DECKS = {
    default: {
      clubs:    { one: 1, two: 1, three: 1 },
      hearts:   { one: 1, two: 1, three: 1 },
      spades:   { one: 1, two: 1, three: 1 },
      diamonds: { one: 1, two: 1, three: 1 }
    }
  }

  def deck
    @deck ||= session.decks.find_by(key: 'default')
  end

  def round_one
    deck.deal_cards(session.players, 4)
  end

  def round_two
    deck.deal_cards(session.players, 3)
  end
end
