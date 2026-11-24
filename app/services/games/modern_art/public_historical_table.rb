class Games::ModernArt::PublicHistoricalTable
  def self.call(session, fields)
    history = fields.include?("history")
    hands = fields.include?("hands")
    frames = history ? session.frames.where(action: Games::ModernArt::HistoricalTable::ACTIONS)
      .where(kind: [ nil, "engine", "observation", "correction" ]).order(:sequence, :id).to_a : []
    card_plays = frames.select { |frame| frame.action == "card_played" && [ nil, "engine" ].include?(frame.kind) }
    projection = Games::ModernArt::Board.new(SessionFrame::Snapshot.call(session), card_plays, nil,
      reveal_completed_hands: hands).call
    metadata = fields.include?("badges") && fields.include?("names") ? Representers::GameSession.new(session, {}).historical_metadata : {}
    players = projection.fetch(:players).map.with_index(1) do |seat, number|
      public_seat = {
        id: number, name: HistoricalExplorer.display_name(seat[:name], number, fields),
        hand: seat[:hand]&.map { |card| public_card(card) },
        handCount: hands ? seat[:handCount] : nil,
        score: fields.include?("final_cash") ? seat[:score] : nil,
        winner: seat[:winner]
      }
      [ public_seat, metadata.fetch(seat[:id], {}) ]
    end
    roster = players.map(&:first)
    badges = players.to_h { |seat, badges| [ seat[:id], badges ] }
    board = { phase: "completed", artists: projection.fetch(:artists),
      played: history ? projection.fetch(:played).map { |card| public_card(card) } : [] }
    Games::ModernArt::HistoricalTable.call(board, roster: roster, metadata: badges, frames: frames,
      complete: complete_replay?(session)).merge(publicHistory: true, publicHands: hands,
        publicFinalCash: fields.include?("final_cash"), publicEvents: history)
  end

  def self.complete_replay?(session)
    SessionFrame::Replay.call(session.frames.order(:sequence)).dig("session", "state") == "completed"
  rescue SessionFrame::Replay::Unavailable
    false
  end
  private_class_method :complete_replay?

  def self.public_card(card)
    card.slice(:id, :name, :value, :label, :color, :iconClass)
  end
  private_class_method :public_card
end
