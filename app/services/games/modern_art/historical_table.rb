class Games::ModernArt::HistoricalTable
  SEASONS = Play::ModernArt::PLAY_SEQUENCE
  ACTIONS = %w[card_played player_passed player_pass auction_result round_payout payment].freeze

  def self.call(board, roster:, metadata:, frames:, complete: true, viewer_id: nil)
    phase = board[:phase]
    concluded = phase == "completed"
    season = SEASONS.index(phase).then { |index| index && index + 1 }
    sales = board.fetch(:sales, [])
    cards = board.fetch(:played, []).index_by { |card| card.fetch(:id) }
    players = roster.map do |seat|
      badges = metadata.fetch(seat[:id], {}).merge(seat.slice(:score, :winner, :captain))
      holdings = sales.select { |sale| sale[:buyerId] == seat[:id] }.filter_map { |sale| cards[sale[:cardId]] }
      { seat: seat[:id], name: seat[:name], handCount: seat[:handCount], hand: seat[:hand],
        holdings: holdings, badges: badges, score: seat[:score], winner: seat[:winner],
        finalCash: concluded ? seat[:score] : nil }
    end
    hand = players.find { |seat| seat[:seat] == viewer_id }&.fetch(:hand)
    actions = frames.filter_map do |frame|
      next unless frame.sequence&.positive? && ACTIONS.include?(frame.action) && frame.kind != "checkpoint"

      card = frame.action == "card_played" ? cards[frame.subject_id] : nil
      verb = frame.action.humanize
      description = [ verb, card&.fetch(:label, nil) ].compact.join(" · ")
      description = "Correction · #{description}" if frame.kind == "correction"
      { frame: frame.sequence, description: description }
    end
    {
      historical: true, completeReplay: complete, phase: "historical", season: season, concluded: concluded,
      turn: concluded ? nil : board[:currentPlayerId], names: players.to_h { |seat| [ seat[:seat], seat[:name] ] },
      auction: { cards: board.fetch(:offer, []), sales: sales },
      hand: hand || [], handKnown: !hand.nil?, viewerSeat: viewer_id, legal: {}, seasons: nil,
      artists: board.fetch(:artists, []).map { |artist| { key: artist.fetch("name"), name: artist.fetch("name"), color: artist["color"] } },
      market: season && board.fetch(:played, []).select { |card| card[:season] == phase }.group_by { |card| card[:name] }.transform_values(&:size),
      players: players, recent: actions.last(8), actionHistory: actions, played: cards.values
    }
  end
end
