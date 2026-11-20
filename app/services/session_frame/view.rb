class SessionFrame::View
  attr_reader :frames, :selected, :state

  def initialize(frames, cursor:)
    @frames = frames
    raise SessionFrame::Replay::Unavailable, "Frame is outside this history" unless cursor.between?(1, frames.size)

    @selected = frames.fetch(cursor - 1)
    @state = SessionFrame::Replay.call(frames, through: cursor)
    @prefix = frames.take(cursor)
    @checkpoint = @prefix.reverse_each.find { |frame| frame.kind == "checkpoint" }
  end

  def for_viewer(viewer)
    roster = state.fetch("players")
    seats = roster.reject { |player| player["removed_at"] }.sort_by { |player| [ player["turn_order"] || 0, player["id"] ] }
    own = seats.find { |player| player["user_id"] == viewer.id }
    cards = state.fetch("cards")
    show_hands = own && state.dig("session", "completed_at")
    reports = @prefix.select { |frame| %w[observation correction].include?(frame.kind) }
    superseded = reports.filter_map(&:corrects_frame_id).to_set

    {
      cursor: selected.sequence, last: frames.size, checkpoint: @checkpoint.sequence,
      event: event(selected, roster),
      phase: state.dig("session", "state"),
      currentPlayerId: state.dig("session", "current_player_id"),
      players: seats.map do |player|
        hand = cards.select { |card| card["player_id"] == player["id"] && card["dealt_at"] && !card["played_at"] && !card["discarded_at"] }
        { id: player["id"], name: player.dig("identity", "name"), score: player["score"], winner: player["winner"],
          captain: player["table_captain"],
          handCount: hand.size, hand: (hand.map { |card| visible_card(card) } if show_hands || player == own) }
      end,
      played: cards.select { |card| card["played_at"] }.sort_by { |card| [ card["played_at"], card["id"] ] }.map { |card| visible_card(card) },
      observations: reports.map do |frame|
        data = Games::ModernArt::Observations::FIELDS.fetch(frame.action, []).index_with do |field|
          value = frame.payload[field]
          case field
          when "card_id"
            card = cards.find { |entry| entry["id"] == value && entry["played_at"] }
            visible_card(card)&.fetch(:label) if card
          when "buyer_id", "player_id", "payer_id", "payee_id"
            player_name(roster, value)
          else
            value if value.is_a?(Integer)
          end
        end
        event(frame, roster).merge(data: data, superseded: superseded.include?(frame.id),
          context: sequence_for(frame.context_frame_id), corrects: sequence_for(frame.corrects_frame_id))
      end
    }
  end

  private

  def event(frame, roster)
    { sequence: frame.sequence, kind: frame.kind, action: frame.action, phase: frame.state,
      actor: actor_name(frame, roster), actorKind: frame.actor_kind,
      recordedAt: frame.created_at.iso8601(6), occurredAt: frame.occurred_at&.iso8601(6) }
  end

  def actor_name(frame, roster)
    return "System" unless frame.acting_player_id

    player_name(roster, frame.acting_player_id) || "Player"
  end

  def player_name(roster, id)
    roster.find { |entry| entry["id"] == id }&.dig("identity", "name") if id
  end

  def sequence_for(id)
    @prefix.find { |frame| frame.id == id }&.sequence if id
  end

  def visible_card(card)
    definition = card.fetch("definition")
    { id: card.fetch("id"), label: "#{definition.fetch('name').titleize} · #{definition.fetch('value').titleize}",
      playerId: card["player_id"] }
  end
end
