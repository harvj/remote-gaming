require 'rails_helper'

RSpec.describe 'GameSession' do
  let(:game)    { create(:game, :cards) }
  let(:user)    { create(:user) }
  let(:session) { game.sessions.last }
  let(:player)  { session.players.first }

  before { new_session }

  it 'is created when corresponding Play class is called' do
    expect(session.game).to eq game
    expect(session.state).to eq 'waiting'
    expect(session.uid).to be_present
    expect(session.players).to be_empty
    expect(session.decks).to be_empty
    expect(session.cards).to be_empty
  end

  context '#playable' do
    it 'is playable only after reaching min players' do
      expect(session).not_to be_playable
      add_player
      expect(session).to be_playable
    end
  end

  context 'state transitions' do
    it 'in initial state' do
      expect(session.next_action).to eq 'started'
    end

    it 'does not start without min players' do
      game.play_class.(session)
      expect(session.state).to eq 'waiting'
      expect(session).to be_waiting
      expect(session.transition_actions).to be_empty
    end

    it 'does start with player count >= min_players' do
      start_session # started
      expect(session.state).to eq 'started'
      expect(session).to be_started
      expect(session.decks.count).to eq 1
      expect(session.cards.count).to eq 12
      expect(session.state).to eq 'started'
      expect(session.transition_actions).to eq %w[started]
      expect(session.next_action).to eq 'round_one'
    end

    it 'performs custom state action' do
      start_session
      session_proceed # round one
      expect(session.cards.dealt.count).to eq 4
      expect(player.cards.count).to eq 4
      expect(session.state).to eq 'round_one'
      expect(session.transition_actions).to eq %w[started round_one]
      expect(session.next_action).to eq 'round_two'
    end

    it 'performs follow up action' do
      start_session
      2.times { session_proceed } # round two
      expect(session.cards.dealt.count).to eq 7
      expect(player.cards.count).to eq 7
      expect(session.state).to eq 'round_two'
      expect(session.transition_actions).to eq %w[started round_one round_two]
      expect(session.next_action).to eq 'completed'
    end

    it 'can be completed' do
      start_session
      3.times { session_proceed } # completed
      expect(session.cards.dealt.count).to eq 7
      expect(player.cards.count).to eq 7
      expect(session.state).to eq 'completed'
      expect(session.transition_actions).to eq %w[started round_one round_two completed]
      expect(session.next_action).to eq nil
    end

    it 'does nothing if called when completed' do
      start_session
      4.times { session_proceed }
      expect(session.state).to eq 'completed'
      expect(session.transition_actions.count).to eq 4
      expect(session.next_action).to eq nil
    end
  end
end
