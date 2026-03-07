module Representers
  class SessionCard < Representers::Base
    def build_object(session_card)
      @session_card = session_card
      deck = session_card.session_deck
      card = session_card.card
      {
        active: session_card.active?,
        color: card.color,
        dealt: session_card.dealt?,
        dealtAt: session_card.dealt_at_milli,
        dealtDuringState: dealt_during_state,
        deckKey: deck.key,
        discarded: session_card.discarded?,
        discardedAt: session_card.discarded_at_milli,
        iconClass: card.icon_class,
        id: session_card.id,
        name: card.name.titleize,
        nameSort: card.name_sort,
        playableOutOfTurn: session_card.playable_out_of_turn?,
        played: session_card.played?,
        playedAt: session_card.played_at_milli,
        playerId: session_card.player_id,
        status: session_card.status.titleize,
        tradeable: session_card.tradeable?,
        validAction: session_card.valid_action,
        value: card.value.titleize,
        valueSort: card.value_sort,
        updatePath: session_card_path(session_card)
      }
    end

    attr_reader :session_card

    def dealt_during_state
      return "Undealt" if !session_card.dealt?
      return "Unknown" if !session_card.dealt_during_state
      "Dealt #{session_card.dealt_during_state.titleize}"
    end
  end
end
