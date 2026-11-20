class SessionFrame::Branch
  class Unsupported < StandardError; end
  RULES_VERSION = Play::ModernArt::RULES_VERSION

  def self.allowed?(table, viewer)
    ExperimentalAccess.enabled? && viewer && !viewer.dummy? && table.experimental? &&
      table.experiment_owner_id == viewer.id && table.game.key == "modern_art"
  end

  def self.supported?(view, viewer)
    state = view.state
    return false unless state && view.selected.kind == "checkpoint"

    seats = state.fetch("players")
    state.dig("game", "rules_version") == RULES_VERSION &&
      Play::ModernArt::PLAY_SEQUENCE.include?(state.dig("session", "state")) &&
      seats.any? { |seat| seat["user_id"] == viewer.id && seat["table_captain"] && !seat["removed_at"] } &&
      seats.all? { |seat| !seat["removed_at"] && (seat["user_id"] == viewer.id || seat.dig("identity", "kind") == "dummy") }
  end

  def self.call(table, viewer:, cursor:)
    raise ActiveRecord::RecordNotFound unless allowed?(table, viewer)

    table.with_lock do
      unless cursor.between?(1, table.frames.maximum(:sequence).to_i)
        raise Unsupported, "The selected frame cannot be branched."
      end

      frames = table.frames.where(sequence: ..cursor).order(:sequence).to_a
      view = SessionFrame::View.new(frames, cursor:)
      raise Unsupported, "Choose a supported gameplay checkpoint in this private experiment." unless supported?(view, viewer)

      new(table, viewer, view).copy
    end
  rescue SessionFrame::Replay::Unavailable, KeyError
    raise Unsupported, "The selected frame cannot be branched."
  end

  def initialize(table, viewer, view)
    @source = table
    @viewer = viewer
    @view = view
    @state = view.state
    @players = {}
    @identities = {}
    @decks = {}
    @cards = {}
    @frames = {}
  end

  def copy
    validate_catalog!
    @branch = @source.game.sessions.create!(uid: SecureRandom.hex(16), state: "waiting",
      experimental: true, experiment_owner: @viewer, parent_session: @source,
      fork_frame: @view.selected, branch_rules_version: RULES_VERSION)
    copy_players
    copy_cards
    @branch.update!(session_fields(@state.fetch("session")).merge(current_player_id: player_id(@state.dig("session", "current_player_id"))))
    @view.frames.each { |frame| copy_frame(frame) }
    @branch
  end

  private

  def validate_catalog!
    game_fields = %w[id key min_players max_players]
    unless @source.game.slice(*game_fields) == @state.fetch("game").slice(*game_fields)
      raise Unsupported, "The recorded table rules differ from the current rules."
    end

    catalog = @source.game.cards.where(id: @state.fetch("cards").pluck("card_id")).index_by(&:id)
    return if @state.fetch("cards").all? do |card|
      catalog[card.fetch("card_id")]&.slice(*SessionFrame::Snapshot::CATALOG_FIELDS) == card.fetch("definition")
    end

    raise Unsupported, "The recorded card catalog differs from the current rules."
  end

  def copy_players
    @state.fetch("players").each do |seat|
      user = if seat.fetch("user_id") == @viewer.id
        @viewer
      else
        handle = SecureRandom.hex(12)
        User.create!(name: "#{seat.dig('identity', 'name')} · #{handle.first(6)}", username: "dummy_#{handle}", dummy: true)
      end
      @identities[seat.fetch("user_id")] = user
      player = @branch.all_players.create!(seat.slice(*SessionFrame::Snapshot::PLAYER_FIELDS)
        .except("id", "user_id", "next_player_id").merge(user: user, game_id: @source.game_id))
      @players[seat.fetch("id")] = player
      player.create_dummy_access!(expires_at: Time.current) if user.dummy?
    end

    @state.fetch("players").each do |seat|
      @players.fetch(seat.fetch("id")).update!(next_player_id: player_id(seat["next_player_id"]))
    end
  end

  def copy_cards
    @state.fetch("decks").each do |deck|
      @decks[deck.fetch("id")] = @branch.decks.create!(key: deck.fetch("key"))
    end

    @state.fetch("cards").each do |card|
      @cards[card.fetch("id")] = @branch.cards.create!(card.slice(*SessionFrame::Snapshot::CARD_FIELDS)
        .except("id", "player_id", "session_deck_id").merge(
          player_id: player_id(card["player_id"]), session_deck: @decks.fetch(card.fetch("session_deck_id"))))
    end
  end

  def copy_frame(frame)
    subject = case frame.subject_type
    when "GameSession" then @branch
    when "Player" then @players.fetch(frame.subject_id)
    when "SessionCard" then @cards.fetch(frame.subject_id)
    when "SessionDeck" then @decks.fetch(frame.subject_id)
    else raise Unsupported, "An event uses an unsupported subject."
    end

    @frames[frame.id] = @branch.frames.create!(
      frame.slice(:sequence, :format_version, :kind, :action, :state, :game_key, :actor_kind, :occurred_at, :created_at)
        .merge(subject: subject, payload: copy_payload(frame),
          acting_player_id: player_id(frame.acting_player_id), affected_player_id: player_id(frame.affected_player_id),
          previous_frame_id: frame_id(frame.previous_frame_id), context_frame_id: frame_id(frame.context_frame_id),
          corrects_frame_id: frame_id(frame.corrects_frame_id))
    )
  end

  def copy_payload(frame)
    return copy_checkpoint(frame.payload) if frame.kind == "checkpoint"

    payload = frame.payload.deep_dup
    if %w[observation correction].include?(frame.kind)
      %w[buyer_id payer_id payee_id player_id].each do |key|
        payload[key] = player_id(payload[key]) if payload.key?(key)
      end
      payload["card_id"] = @cards.fetch(payload["card_id"]).id if payload.key?("card_id")
    elsif frame.action == "turn_order_assigned"
      payload["player_ids"] = payload.fetch("player_ids").map { |id| player_id(id) }
    end
    payload
  end

  def copy_checkpoint(source)
    payload = source.deep_dup
    payload.fetch("session").merge!("id" => @branch.id, "uid" => @branch.uid,
      "created_at" => @branch.created_at.iso8601(6),
      "current_player_id" => player_id(payload.dig("session", "current_player_id")))
    payload.fetch("players").each do |seat|
      user = @identities.fetch(seat.fetch("user_id"))
      seat.merge!("id" => player_id(seat.fetch("id")), "user_id" => user.id, "next_player_id" => player_id(seat["next_player_id"]))
      if user.dummy?
        seat["identity"] = user.slice("id", "username", "name").merge("kind" => "dummy")
      end
    end
    payload.fetch("decks").each { |deck| deck["id"] = @decks.fetch(deck.fetch("id")).id }
    payload.fetch("cards").each do |card|
      card.merge!("id" => @cards.fetch(card.fetch("id")).id, "player_id" => player_id(card["player_id"]),
        "session_deck_id" => @decks.fetch(card.fetch("session_deck_id")).id)
    end
    payload
  end

  def session_fields(state)
    state.slice(*SessionFrame::Snapshot::SESSION_FIELDS).except("id", "uid", "game_id", "created_at", "current_player_id")
  end

  def player_id(id)
    @players.fetch(id).id if id
  end

  def frame_id(id)
    @frames.fetch(id).id if id
  end
end
