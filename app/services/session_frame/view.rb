class SessionFrame::View
  attr_reader :frames, :selected, :state

  def initialize(frames, cursor:, validated: false)
    @frames = frames
    raise SessionFrame::Replay::Unavailable, "Frame is outside this history" unless cursor.between?(1, frames.size)

    @selected = frames.fetch(cursor - 1)
    SessionFrame::Replay.validate!(frames) unless validated
    @prefix = frames.take(cursor)
    @checkpoint = @prefix.reverse_each.find { |frame| frame.kind == "checkpoint" }
    @state = reconstruct(cursor)
  end

  def for_viewer(viewer)
    roster = (state || @checkpoint.payload).fetch("players")
    cards = state ? state.fetch("cards") : []
    reports = @prefix.select { |frame| %w[observation correction].include?(frame.kind) }
    superseded = reports.filter_map(&:corrects_frame_id).to_set
    board = state ? Games::ModernArt::Board.new(state, @prefix, viewer).call : {}

    board.merge(
      cursor: selected.sequence, last: frames.size, checkpoint: @checkpoint.sequence,
      event: event(selected, roster), available: state.present?,
      observations: reports.map do |frame|
        data = Games::ModernArt::Observations::FIELDS.fetch(frame.action, []).index_with do |field|
          value = frame.payload[field]
          case field
          when "card_id"
            card = cards.find { |entry| entry["id"] == value && entry["played_at"] }
            Games::ModernArt::Board.card(card).fetch(:label) if card
          when "buyer_id", "player_id", "payer_id", "payee_id"
            player_name(roster, value)
          else
            value if value.is_a?(Integer)
          end
        end
        event(frame, roster).merge(data: data, superseded: superseded.include?(frame.id),
          context: sequence_for(frame.context_frame_id), corrects: sequence_for(frame.corrects_frame_id))
      end
    )
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

  def reconstruct(cursor)
    SessionFrame::Replay.state_at(frames, cursor)
  rescue SessionFrame::Replay::Unavailable
    nil
  end
end
