# Version 1 recorded outcomes (card and seat IDs) but omitted database write
# times and some created records. A closing checkpoint supplies those values.
# Apply them only at the event which the v1 engine emitted after the write.
class SessionFrame::Replay::ModernArtInterval
  Error = SessionFrame::Replay::Unavailable
  PHASES = %w[waiting started season_one season_two season_three season_four completed].freeze

  def initialize(state, final)
    @state = state
    @final = final
    @session = state.fetch("session")
    @players = state.fetch("players").index_by { |row| row.fetch("id") }
    @cards = state.fetch("cards").index_by { |row| row.fetch("id") }
    @final_players = final.fetch("players").index_by { |row| row.fetch("id") }
    @final_cards = final.fetch("cards").index_by { |row| row.fetch("id") }
  end

  def reconstruct(events, cursor)
    selected = nil
    events.each do |frame|
      finish_completion
      apply(frame) if frame[:kind] == "engine"
      selected = @state.deep_dup if frame[:sequence] == cursor
    end
    finish_completion
    require_evidence(@state == @final && selected)
    selected
  rescue KeyError, IndexError, TypeError
    raise Error, "Incomplete Modern Art event evidence"
  end

  private

  def apply(frame)
    payload = frame[:payload]
    case frame[:action]
    when "card_dealt", "card_played", "card_discarded"
      apply_card(frame)
    when "turn_order_assigned"
      assign_turn_order(payload.fetch("player_ids"), frame[:affected_player_id])
    when "turn_advanced"
      advance_turn(frame[:acting_player_id], frame[:affected_player_id])
    when "player_created"
      id = frame[:subject_id]
      require_evidence(!@players.key?(id))
      @players[id] = @final_players.fetch(id).deep_dup
      @state["players"] = @players.values.sort_by { |player| player.fetch("id") }
    when "player_left", "player_rejoined"
      change_membership(frame)
    when "score_reported"
      report_score(frame[:subject_id], payload.fetch("score"))
    when "player_pass", "player_passed", "free_single_double"
      # These markers change legal actions through history, not snapshot fields.
    else
      transition(frame[:action], payload)
    end
    require_evidence(@session["state"] == frame[:state])
  end

  def apply_card(frame)
    id = frame[:subject_id]
    card = @cards.fetch(id)
    final = @final_cards.fetch(id)
    field = { "card_dealt" => "dealt_at", "card_played" => "played_at", "card_discarded" => "discarded_at" }.fetch(frame[:action])
    require_evidence(frame[:subject_type] == "SessionCard" && frame[:payload].fetch("card") == card["definition"])
    require_evidence(card[field].nil? && final[field].is_a?(String))
    if field == "dealt_at"
      require_evidence(final["player_id"] == frame[:affected_player_id])
      card["player_id"] = frame[:affected_player_id]
    end
    card[field] = final[field]
  end

  def assign_turn_order(ids, first)
    require_evidence(@session["state"] == "started" && @session["started_at"].nil? &&
      @cards.empty? && @state["decks"].empty? && ids.present? && ids.first == first &&
      ids.sort == @players.values.reject { |player| player["removed_at"] }.pluck("id").sort)
    @session["started_at"] = session_timestamp("started_at")
    @state["decks"] = @final.fetch("decks").deep_dup
    @cards = @final_cards.transform_values do |card|
      card.merge("player_id" => nil, "dealt_at" => nil, "played_at" => nil, "discarded_at" => nil)
    end
    @state["cards"] = @cards.values.sort_by { |card| card.fetch("id") }
    ids.each_with_index do |id, index|
      @players.fetch(id).merge!("turn_order" => index + 1, "next_player_id" => ids[(index + 1) % ids.size])
    end
    @session["current_player_id"] = first
    @players.fetch(first)["action_phase"] = "active"
  end

  def advance_turn(from, to)
    player = @players.fetch(from)
    require_evidence(@session["current_player_id"] == from && player["next_player_id"] == to)
    player["action_phase"] = "idle"
    @session["current_player_id"] = to
    @players.fetch(to)["action_phase"] = "active"
  end

  def change_membership(frame)
    player = @players.fetch(frame[:subject_id])
    if frame[:action] == "player_left"
      was_captain = player["table_captain"]
      timestamp = @final_players.fetch(player.fetch("id")).fetch("removed_at")
      require_evidence(player["removed_at"].nil? && timestamp.is_a?(String))
      player.merge!("removed_at" => timestamp, "table_captain" => false)
      successor = @players.values.reject { |seat| seat["removed_at"] }.min_by { |seat| seat.fetch("id") }
      successor["table_captain"] = true if was_captain && successor
    else
      require_evidence(player["removed_at"].present?)
      has_captain = @players.values.any? { |seat| seat["table_captain"] && !seat["removed_at"] }
      player.merge!("removed_at" => nil, "table_captain" => !has_captain)
    end
  end

  def report_score(id, score)
    @players.fetch(id)["score"] = score
    roster = @players.values.reject { |player| player["removed_at"] }
    return unless roster.all? { |player| !player["score"].nil? }

    winner = roster.min_by { |player| [ -player.fetch("score"), player.fetch("id") ] }
    roster.each { |player| player["winner"] = false if player["winner"] && player != winner }
    winner["winner"] = true
  end

  def transition(action, payload)
    current_index = PHASES.index(@session["state"])
    require_evidence(current_index && PHASES[current_index + 1] == action &&
      payload == { "from" => @session["state"], "to" => action })
    # started_at and completed_at are written after the corresponding phase
    # marker. The former becomes observable at turn order; the latter at close.
    @session["state"] = action
    @completion_at_close = action == "completed"
  end

  def finish_completion
    return unless @completion_at_close

    @session["completed_at"] = session_timestamp("completed_at")
    @completion_at_close = false
  end

  def session_timestamp(field)
    value = @final.fetch("session").fetch(field)
    require_evidence(value.is_a?(String))
    value
  end

  def require_evidence(condition)
    raise Error, "Recorded events do not account for this checkpoint" unless condition
  end
end
