class SessionFrame::Replay
  class Unavailable < StandardError; end

  # The envelope is validated separately from reconstruction so an unsupported
  # intermediate frame does not prevent navigation to a recorded checkpoint.
  def self.validate!(frames)
    previous_id = nil
    session_id = frames.first&.[](:game_session_id)
    frames.each_with_index do |frame, index|
      unless frame[:game_session_id] == session_id &&
          %w[checkpoint engine observation correction].include?(frame[:kind]) &&
          frame[:format_version] == 1 && frame[:sequence] == index + 1 && frame[:previous_frame_id] == previous_id &&
          (index.positive? || (frame[:kind] == "checkpoint" && frame[:action] == "session_created"))
        raise Unavailable, "History has a gap or unsupported format"
      end
      checkpoint(frame) if frame[:kind] == "checkpoint"
      previous_id = frame[:id]
    end
    raise Unavailable, "No complete initial checkpoint" unless previous_id
  end

  def self.call(frames, through: nil)
    frames = frames.to_a
    validate!(frames)
    state_at(frames, through || frames.size)
  end

  # Accepts an already validated history. Only the selected command interval
  # needs reducing, including its closing checkpoint for consistency checking.
  def self.state_at(frames, cursor)
    raise Unavailable, "Frame is outside this history" unless cursor.between?(1, frames.size)

    opening = frames.rindex { |frame| frame[:sequence] <= cursor && frame[:kind] == "checkpoint" }
    state = checkpoint(frames.fetch(opening)).deep_dup
    interval = frames.drop(opening + 1)
    closing = interval.index { |frame| frame[:kind] == "checkpoint" }
    events = interval.take(closing || interval.size)
    selected = events.take(cursor - opening - 1)
    return state unless selected.any? { |frame| frame[:kind] == "engine" }

    unless closing && state.dig("game", "key") == "modern_art" && state.dig("game", "rules_version") == 1
      raise Unavailable, "No verified Modern Art command interval"
    end

    final = checkpoint(interval.fetch(closing))
    ModernArtInterval.new(state, final).reconstruct(events, cursor)
  end

  def self.checkpoint(frame)
    state = frame[:payload]
    unless state.is_a?(Hash) && state["session"].is_a?(Hash) && state["game"].is_a?(Hash) &&
        %w[players decks cards].all? { |key| state[key].is_a?(Array) }
      raise Unavailable, "Incomplete checkpoint"
    end
    state
  end
  private_class_method :checkpoint
end
