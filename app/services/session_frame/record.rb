class SessionFrame::Record
  class InvalidAction < StandardError; end

  def self.call(session, action:)
    key = command_key(session)
    return yield if ActiveSupport::IsolatedExecutionState[key]

    session.with_lock(requires_new: true) do
      raise InvalidAction, "Historical sessions are read-only" unless session.replayable?

      ActiveSupport::IsolatedExecutionState[key] = true
      begin
        before = session.frames.order(sequence: :desc).first
        previous_state = session.frames.checkpoints.order(sequence: :desc).first.payload
        result = yield
        state = SessionFrame::Snapshot.call(GameSession.find(session.id))
        if session.frames.maximum(:sequence) != before.sequence || state != previous_state
          SessionFrame::Create.!(session, kind: "checkpoint", action: action, subject: session,
            payload: state)
          ActiveRecord.after_all_transactions_commit do
            session.broadcast_live!
          end
        end
        result
      ensure
        ActiveSupport::IsolatedExecutionState.delete(key)
      end
    end
  end

  def self.require_command!(session)
    unless ActiveSupport::IsolatedExecutionState[command_key(session)]
      raise InvalidAction, "Game changes must run as a recorded command"
    end
  end

  def self.command_key(session)
    "session-frame-command-#{session.id}"
  end
  private_class_method :command_key
end
