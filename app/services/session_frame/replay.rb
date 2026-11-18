class SessionFrame::Replay
  class Unavailable < StandardError; end

  # Accept immutable frame rows (or serialized frame hashes), without loading a session.
  def self.call(frames, through: nil)
    state = nil
    previous_id = nil
    session_id = nil
    frames.each_with_index do |frame, index|
      sequence = index + 1
      break if through && sequence > through

      session_id = frame[:game_session_id] if index.zero?
      unless frame[:game_session_id] == session_id &&
          %w[checkpoint engine observation correction].include?(frame[:kind]) &&
          frame[:format_version] == 1 && frame[:sequence] == sequence && frame[:previous_frame_id] == previous_id &&
          (index.positive? || (frame[:kind] == "checkpoint" && frame[:action] == "session_created"))
        raise Unavailable, "History has a gap or unsupported format"
      end
      if frame[:kind] == "checkpoint"
        state = frame[:payload]
        raise Unavailable, "Incomplete checkpoint" unless state.is_a?(Hash) && state["session"]
      end
      previous_id = frame[:id]
    end
    raise Unavailable, "No complete initial checkpoint" unless state

    state.deep_dup
  end
end
