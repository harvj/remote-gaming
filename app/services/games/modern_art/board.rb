class Games::ModernArt::Board
  def initialize(state, events, viewer, reveal_completed_hands: false)
    @session = state.fetch("session")
    @players = state.fetch("players").reject { |player| player["removed_at"] }
      .sort_by { |player| [ player["turn_order"] || 0, player.fetch("id") ] }
    @cards = state.fetch("cards")
    @events = events
    @viewer = @players.find { |player| player["user_id"] == viewer.id } if viewer
    @reveal_completed_hands = reveal_completed_hands
  end

  def call
    plays = @events.select { |event| event.action == "card_played" }.index_by(&:subject_id)
    deals = @events.select { |event| event.action == "card_dealt" }.index_by(&:subject_id)
    played = @cards.select { |card| card["played_at"] }
      .sort_by { |card| [ plays[card["id"]]&.sequence || 0, card["played_at"], card["id"] ] }
    painted = played.map { |card| self.class.card(card).merge(season: plays[card["id"]]&.state) }
    {
      phase: @session["state"], currentPlayerId: @session["current_player_id"],
      players: seats(deals), played: painted, offer: current_offer(painted),
      sales: reported_sales(painted),
      discarded: @cards.select { |card| card["discarded_at"] && !card["played_at"] }
        .group_by { |card| card["player_id"] }.map do |id, cards|
          { playerId: id, count: cards.size, cards: (cards.map { |card| self.class.card(card) } if visible_hand?(id)) }
        end,
      undealt: @cards.count { |card| !card["dealt_at"] },
      artists: @cards.map { |card| card.fetch("definition") }.uniq { |definition| definition["name"] }
        .sort_by { |definition| definition["name_sort"] }.map { |definition| definition.slice("color").merge("name" => definition.fetch("name").titleize) }
    }
  end

  def self.card(card)
    definition = card.fetch("definition")
    name = definition.fetch("name").titleize
    value = definition.fetch("value").titleize
    { id: card.fetch("id"), name: name, value: value, label: "#{name} · #{value}",
      color: definition["color"], iconClass: definition["icon_class"], playerId: card["player_id"] }
  end

  private

  def seats(deals)
    @players.map do |player|
      id = player.fetch("id")
      hand = @cards.select { |card| card["player_id"] == id && card["dealt_at"] && !card["played_at"] && !card["discarded_at"] }
        .sort_by { |card| [ deals[card["id"]]&.sequence || 0, card["dealt_at"], card["id"] ] }
      { id: id, name: player.dig("identity", "name"), city: player.dig("role", "name")&.titleize,
        score: player["score"], winner: player["winner"], captain: player["table_captain"],
        handCount: hand.size, hand: (hand.map { |card| self.class.card(card) } if visible_hand?(id)) }
    end
  end

  def visible_hand?(player_id)
    return true if @viewer && player_id == @viewer["id"]

    player_id && @session["completed_at"] && (@viewer || @reveal_completed_hands)
  end

  def reported_sales(painted)
    reports = @events.select { |frame| %w[observation correction].include?(frame.kind) && frame.action == "auction_result" }
    superseded = reports.filter_map(&:corrects_frame_id).to_set
    played_ids = painted.pluck(:id).to_set
    current = reports.reject { |frame| superseded.include?(frame.id) }.group_by { |frame| frame.payload["card_id"] }
    current.values.filter_map do |entries|
      next unless entries.one?

      frame = entries.first
      card_id, buyer_id, amount = frame.payload.values_at("card_id", "buyer_id", "winning_bid")
      buyer = @players.find { |player| player["id"] == buyer_id }
      { cardId: card_id, buyer: buyer.dig("identity", "name"), buyerId: buyer_id, amount: amount } if buyer && played_ids.include?(card_id)
    end
  end

  def current_offer(painted)
    season = @session["state"]
    return [] unless Play::ModernArt::PLAY_SEQUENCE.include?(season)

    last = painted.last
    return [] unless last && last[:season] == season

    # The app records offers and double-auction pairings. The physical table
    # handles bidding, settlement and transfers, which are separate reports.
    previous = painted[-2]
    if last[:value] != "Double" && previous && previous[:season] == season && previous[:name] == last[:name] &&
        previous[:value] == "Double" && !released_between?(previous[:id], last[:id])
      [ previous, last ]
    else
      [ last ]
    end
  end

  def released_between?(first_id, last_id)
    first = @events.find { |event| event.action == "card_played" && event.subject_id == first_id }
    last = @events.find { |event| event.action == "card_played" && event.subject_id == last_id }
    @events.any? { |event| event.action == "free_single_double" && event.sequence.between?(first.sequence, last.sequence) }
  end
end
