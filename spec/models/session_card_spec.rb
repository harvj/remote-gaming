require 'rails_helper'

describe 'SessionCard' do
  let(:game)    { create(:game, :cards) }
  let(:user)    { create(:user) }
  let(:session) { game.sessions.last }

  it 'has access to dealt_during_state' do
    create_and_start_session # started
    expect(session.cards.dealt.last).to be_nil
    session_proceed # round one
    card = session.cards.dealt.last
    expect(card.dealt_during_state).to eq 'round_one'
  end
end
