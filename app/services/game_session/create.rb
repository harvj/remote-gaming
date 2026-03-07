class GameSession::Create < Services::Create
  def apply_pre_processing
    @subject.uid = GameSession.generate_uid
    @subject.state = :waiting
  end
end
