class SessionFrame::Observe
  def self.call(session, user, attributes)
    session.with_lock(requires_new: true) do
      actor = session.players.find_by!(user: user, table_captain: true)
      schema = session.play_class.observation_schema
      unless session.replayable? && schema
        raise SessionFrame::Record::InvalidAction, "Physical reporting is unavailable for this history"
      end

      context = session.frames.checkpoints.find(attributes.fetch("context_frame_id", nil))
      unless context.format_version == 1 && schema.valid_context?(context)
        raise SessionFrame::Record::InvalidAction, "Choose a Modern Art season"
      end

      target = session.frames.observations.find(attributes["corrects_frame_id"]) if attributes["corrects_frame_id"].present?
      type = attributes["type"]
      if target && (target.action != type || session.frames.exists?(corrects_frame_id: target.id))
        raise SessionFrame::Record::InvalidAction, "Corrections must replace the latest report of the same type"
      end

      occurred_at = parse_time(attributes["occurred_at"])
      state = context.payload
      data = schema.validate!(type, attributes["data"], state)
      frame = SessionFrame::Create.!(session, kind: target ? "correction" : "observation",
        action: type, state: context.state, subject: session, acting_player: actor, context_frame: context,
        corrects_frame: target, occurred_at: occurred_at, payload: data).subject
      ActiveRecord.after_all_transactions_commit { session.broadcast_live! }
      frame
    end
  end

  def self.parse_time(value)
    return if value.blank?

    Time.iso8601(value)
  rescue ArgumentError
    raise SessionFrame::Record::InvalidAction, "Use an event time with a time zone"
  end
end
