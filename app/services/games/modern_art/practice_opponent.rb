class Games::ModernArt::PracticeOpponent
  def self.choose(rules, seat)
    choices = rules.legal(seat)
    cards = choices.fetch("card_ids", [])
    return [ "play", cards[(rules.state.fetch("market").values.sum + seat) % cards.size] ] if cards.any?

    ceiling = 8 + 4 * seat + 3 * rules.state.fetch("season")
    ceiling *= rules.state.dig("auction", "lot")&.size || 1
    if choices["price"]
      minimum, maximum = choices.fetch("price")
      return [ "price", (ceiling - 3).clamp(minimum, maximum) ]
    end
    if choices["buy"] && rules.state.dig("auction", "price") <= ceiling
      return [ "buy", nil ]
    end
    if (range = choices["bid"])
      minimum, maximum = range
      return [ "bid", ceiling.clamp(minimum, maximum) ] if minimum <= ceiling
    end
    [ "pass", nil ] if choices["pass"]
  end
end
