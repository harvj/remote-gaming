# Digital auctions for the disposable practice table. The physical-table recorder
# intentionally delegates bids and bank settlement to the people at the table.
class Games::ModernArt::PracticeRules
  class IllegalCommand < StandardError; end

  SEATS = [ 0, 1, 2 ].freeze
  DEAL = [ 10, 6, 6, 0 ].freeze

  attr_reader :state

  def self.start(cards, seed:, first_seat:)
    shuffled = cards.shuffle(random: Random.new(seed))
    game = new({
      "cards" => cards.index_by { |card| card.fetch("id").to_s },
      "deck" => shuffled.pluck("id"), "hands" => [ [], [], [] ], "cash" => [ 100, 100, 100 ],
      "holdings" => [ [], [], [] ], "market" => {}, "seasons" => [], "season" => 1,
      "phase" => "offer", "turn" => first_seat, "recent" => []
    })
    game.deal
    game
  end

  def initialize(state)
    @state = state
  end

  def legal(seat)
    case phase
    when "offer"
      { "card_ids" => seat == state.fetch("turn") ? hand(seat) : [] }
    when "pair"
      ids = hand(seat).select { |id| artist(id) == artist(lot.first) && kind(id) != "double" }
      seat == state.fetch("turn") ? { "card_ids" => ids, "pass" => true } : {}
    when "fixed_price"
      seat == seller ? { "price" => [ cash(seat).zero? ? 0 : 1, cash(seat) ] } : {}
    when "fixed_offer"
      seat == state.fetch("turn") ? { "buy" => cash(seat) >= auction.fetch("price"), "pass" => true } : {}
    when "open"
      return {} if seat == auction["leader"] || auction.fetch("passed").include?(seat)

      { "bid" => bid_range(seat), "pass" => true }
    when "once_around"
      seat == state.fetch("turn") ? { "bid" => bid_range(seat), "pass" => true } : {}
    when "sealed"
      auction.fetch("bids").key?(seat.to_s) ? {} : { "bid" => [ 0, cash(seat) ] }
    when "scoring"
      seat.zero? ? { "advance" => true } : {}
    else
      {}
    end
  end

  def command(seat, action, value = nil)
    choices = legal(seat)
    case action
    when "play"
      require_choice(choices.fetch("card_ids", []).include?(value))
      play(seat, value)
    when "price", "bid"
      range = choices[action]
      require_choice(range && value.is_a?(Integer) && value.between?(*range))
      action == "price" ? set_price(seat, value) : bid(seat, value)
    when "pass", "buy", "advance"
      require_choice(choices[action])
      case action
      when "pass" then pass(seat)
      when "buy" then settle(seat, auction.fetch("price"))
      when "advance" then advance
      end
    else
      raise IllegalCommand
    end
  end

  def deal
    state.fetch("hands").each { |cards| cards.concat(state.fetch("deck").shift(DEAL.fetch(state.fetch("season") - 1))) }
  end

  def projection(seat)
    ending = phase == "complete"
    listing = auction&.slice("seller", "price", "leader", "high")
    listing["cards"] = lot.map { |id| card(id) } if listing
    {
      season: state.fetch("season"), phase: phase, turn: state["turn"], auction: listing,
      hand: hand(seat).map { |id| card(id) }, legal: legal(seat), market: state.fetch("market"),
      seasons: state.fetch("seasons"), recent: state.fetch("recent"),
      players: SEATS.map do |position|
        details = { seat: position, handCount: hand(position).size, holdings: state.fetch("holdings")[position].map { |id| card(id) } }
        details[:cash] = cash(position) if position == seat || ending
        details
      end
    }
  end

  private

  def phase = state.fetch("phase")
  def auction = state["auction"]
  def seller = auction.fetch("seller")
  def lot = auction.fetch("lot")
  def hand(seat) = state.fetch("hands").fetch(seat)
  def cash(seat) = state.fetch("cash").fetch(seat)
  def card(id) = state.fetch("cards").fetch(id.to_s)
  def artist(id) = card(id).fetch("artist")
  def kind(id) = card(id).fetch("kind")
  def next_seat(seat) = (seat + 1) % SEATS.length

  def require_choice(condition)
    raise IllegalCommand unless condition
  end

  def play(seat, id)
    pairing = phase == "pair"
    hand(seat).delete(id)
    state["auction"] = { "seller" => seat, "lot" => [] } unless pairing
    auction["seller"] = seat
    lot << id
    counts = state.fetch("market")
    counts[artist(id)] = counts.fetch(artist(id), 0) + 1
    note("played", seat: seat, card: card(id))
    if counts[artist(id)] == 5 || hands_empty?
      score(seat)
    elsif kind(id) == "double"
      auction["passed"] = []
      state["phase"] = "pair"
    else
      open_auction(kind(id))
    end
  end

  def open_auction(type)
    state["phase"] = type == "fixed" ? "fixed_price" : type
    state["turn"] = type == "once_around" ? next_seat(seller) : (type == "fixed" ? seller : nil)
    auction.merge!("high" => 0, "passed" => [], "bids" => {})
  end

  def set_price(seat, amount)
    auction["price"] = amount
    state["phase"] = "fixed_offer"
    state["turn"] = next_seat(seat)
    note("price", seat: seat, amount: amount)
  end

  def bid_range(seat)
    minimum = auction.fetch("high") + 1
    [ minimum, cash(seat) ] if minimum <= cash(seat)
  end

  def bid(seat, amount)
    if phase == "sealed"
      bids = auction.fetch("bids")
      bids[seat.to_s] = amount
      return unless bids.size == SEATS.size

      priority = [ seller, next_seat(seller), next_seat(next_seat(seller)) ]
      winner = priority.max_by { |position| bids.fetch(position.to_s) }
      note("revealed", amounts: SEATS.map { |position| bids.fetch(position.to_s) })
      return settle(winner, bids.fetch(winner.to_s))
    end

    auction.merge!("leader" => seat, "high" => amount)
    note("bid", seat: seat, amount: amount)
    if phase == "open"
      auction["passed"] = []
    else
      once_around(seat)
    end
  end

  def pass(seat)
    case phase
    when "pair"
      auction.fetch("passed") << seat
      auction.fetch("passed").size == SEATS.size ? settle(seller, 0) : state["turn"] = next_seat(seat)
    when "fixed_offer"
      next_seat(seat) == seller ? settle(seller, auction.fetch("price")) : state["turn"] = next_seat(seat)
    when "once_around"
      once_around(seat)
    when "open"
      auction.fetch("passed") << seat
      challengers = SEATS - [ auction["leader"] ]
      settle(auction["leader"] || seller, auction.fetch("high")) if (challengers - auction.fetch("passed")).empty?
    end
  end

  def once_around(seat)
    seat == seller ? settle(auction["leader"] || seller, auction.fetch("high")) : state["turn"] = next_seat(seat)
  end

  def settle(winner, price)
    state.fetch("cash")[winner] -= price
    state.fetch("cash")[seller] += price unless winner == seller
    state.fetch("holdings")[winner].concat(lot)
    note("sold", seat: winner, seller: seller, amount: price, cards: lot.map { |id| card(id) })
    resume_from(seller)
  end

  def score(last)
    counts = state.fetch("market")
    tiers = counts.keys.sort_by { |key| [ -counts.fetch(key), card_order(key) ] }.first(3)
    tiles = tiers.zip([ 30, 20, 10 ]).to_h
    seasons = state.fetch("seasons")
    values = tiles.transform_keys(&:to_s).to_h do |key, value|
      [ key, value + seasons.sum { |season| season.fetch("tiles").fetch(key, 0) } ]
    end
    payouts = state.fetch("holdings").map { |cards| cards.sum { |id| values.fetch(artist(id), 0) } }
    payouts.each_with_index { |payout, seat| state.fetch("cash")[seat] += payout }
    seasons << { "tiles" => tiles, "values" => values, "payouts" => payouts }
    state["ended"] = state.fetch("season") == 4 || hands_empty?
    state["auction"] = nil
    state["phase"] = "scoring"
    state["turn"] = next_seat(last)
    note("scored")
  end

  def card_order(key)
    state.fetch("cards").values.find { |definition| definition.fetch("artist") == key }.fetch("order")
  end

  def advance
    if state.fetch("ended")
      state["phase"] = "complete"
      state["turn"] = nil
      return
    end

    state["season"] += 1
    state.merge!("market" => {}, "holdings" => [ [], [], [] ])
    deal
    resume_from((state.fetch("turn") - 1) % SEATS.length)
  end

  def resume_from(seat)
    state["auction"] = nil
    state["phase"] = "offer"
    next_player = (1..SEATS.length).map { |step| (seat + step) % SEATS.length }.find { |position| hand(position).any? }
    state["turn"] = next_player
  end

  def hands_empty? = state.fetch("hands").all?(&:empty?)

  def note(type, **fields)
    state.fetch("recent") << fields.stringify_keys.merge("type" => type)
    state.fetch("recent").shift while state.fetch("recent").length > 8
  end
end
