module Representers
  class SessionDeck < Representers::Base
    def build_object(deck)
      {
        id: deck.id,
        key: deck.key,
        cards: Representers::SessionCard.(deck.cards)
      }
    end
  end
end
