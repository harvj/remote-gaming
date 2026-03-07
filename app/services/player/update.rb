class Player::Update < Services::Update
  def apply_post_processing
    check_for_winner
  end

  private

  def check_for_winner
    return unless subject.session.players.all? { |p| p.score.present? }
    subject.session.players.reorder('score desc').first.update_attribute(:winner, true)
  end
end
