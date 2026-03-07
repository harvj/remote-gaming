class SessionCard::Create < Services::Create
  def apply_pre_processing
    subject.game_session_id = parent.game_session_id
  end
end
