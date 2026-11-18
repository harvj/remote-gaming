class Player::Update < Services::Update
  private

  def update(&)
    SessionFrame::Record.call(subject.session, action: "score") { super }
  end

  def apply_pre_processing
    unless subject.session.completed? && subject.removed_at.nil?
      raise SessionFrame::Record::InvalidAction, "Scores can be entered after the game"
    end
  end

  def apply_post_processing
    roster = subject.session.players
    if roster.all? { |player| player.score.present? }
      winner = roster.reorder(score: :desc, id: :asc).first
      roster.where(winner: true).where.not(id: winner.id).update_all(winner: false)
      winner.update!(winner: true)
    end
    SessionFrame::Create.!(subject.session, action: "score_reported", acting_player: subject,
      subject: subject, payload: { score: subject.score, source: "participant" })
  end
end
