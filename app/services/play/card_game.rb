class Play::CardGame < Play::Base
  PLAY_SEQUENCE = %w[round_one round_two]
  DECKS = {
    default: {
      clubs:    { one: 1, two: 1, three: 1 },
      hearts:   { one: 1, two: 1, three: 1 },
      spades:   { one: 1, two: 1, three: 1 },
      diamonds: { one: 1, two: 1, three: 1 }
    }
  }

  def deck
    @deck ||= session.decks.find_by(key: "default")
  end

  def build_card_decks
    DECKS.each do |deck_key, suits|
      session_deck = session.decks.create!(key: deck_key)

      suits.each do |name, values|
        values.each do |value, count|
          count.times do
            SessionCard::Create.!(
              session_deck,
              card: session.game.cards.find_by!(name: name.to_s, value: value.to_s)
            )
          end
        end
      end
    end
  end

  def round_one
    deck.deal_cards(session.players, 4)
  end

  def round_two
    deck.deal_cards(session.players, 3)
  end
end
