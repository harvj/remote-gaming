class GameSession::Create < Services::Create
  def apply_pre_processing
    @subject.uid = SecureRandom.hex(16)
    @subject.state = :waiting
  end

  def apply_post_processing
    SessionFrame::Create.!(subject, kind: "checkpoint", action: "session_created",
      subject: subject, payload: SessionFrame::Snapshot.call(subject))
  end

  private

  def create(&block)
    GameSession.transaction(requires_new: true) { super(&block) }
  end
end
