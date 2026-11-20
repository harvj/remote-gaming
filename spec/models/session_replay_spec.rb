require "rails_helper"

RSpec.describe "Modern Art frame history" do
  let(:game) { create(:game, :modern_art) }
  let(:session) { GameSession::Create.!(game).subject }

  def play_to_completion(session)
    66.times do
      break if session.reload.completed?

      player = session.current_player
      eligible = player.cards.active.select(&:playable?)
      if eligible.empty? && player.possible_actions.include?("pass")
        player.play(action: "pass")
        next
      end
      played_counts = session.played_card_counts_by_state(session.state).to_h { |count| [ count.name, count.count.to_i ] }
      card = eligible.max_by do |item|
        [ played_counts.fetch(item.card.name, 0), item.card.value == "double" ? 0 : 1, -item.id ]
      end
      raise "No playable card or legal pass in #{session.state}" unless card

      card.play
    end
  end

  it "replays a full three-player game, including random deals, turns, phases and scores" do
    members = Array.new(3) { Player::Create.!(create(:user), session: session).subject }
    session.play_class.(session, members.first.user)
    expect(session.reload.state).to eq("season_one")
    expect(session.players.map { |player| player.cards.dealt.count }).to eq([ 10, 10, 10 ])
    expect(session.cards.count).to eq(70)
    expect(session.players.map(&:next_player_id)).to match_array(members.map(&:id))

    card = session.players.find { |player| player.id != session.current_player_id }.cards.active.first
    count = session.frames.count
    expect { card.play }.to raise_error(SessionFrame::Record::InvalidAction)
    expect { session.current_player.play(action: "nonsense") }.to raise_error(SessionFrame::Record::InvalidAction)
    expect(session.frames.count).to eq(count)

    play_to_completion(session)
    expect(session.reload).to be_completed
    expect(session.transition_actions).to eq(%w[started season_one season_two season_three season_four completed])
    expect(session.cards.dealt.count).to eq(66)
    members.each_with_index { |player, index| Player::Update.!(player.reload, score: 10 + index) }

    frames = session.frames.order(:sequence).map(&:attributes).map(&:symbolize_keys)
    expect(frames.pluck(:sequence)).to eq((1..frames.size).to_a)
    final_state = SessionFrame::Snapshot.call(session.reload)
    expect(SessionFrame::Replay.call(frames)).to eq(final_state)
    expect(SessionFrame::Replay.call(frames, through: 1).fetch("players")).to eq([])
    expect { SessionFrame::Replay.call(frames.drop(1)) }.to raise_error(SessionFrame::Replay::Unavailable)
    expect(session.winner).to eq(members.last)

    # The entire stream can be replayed even if the current tables disagree.
    session.update_column(:state, "waiting")
    expect(SessionFrame::Replay.call(frames)).to eq(final_state)
  end

  it "keeps the archived single-double pass sequence" do
    members = Array.new(3) { Player::Create.!(create(:user), session: session).subject }
    opening_deals = members.size
    allow_any_instance_of(SessionDeck).to receive(:next_card).and_wrap_original do |original|
      if opening_deals.positive?
        opening_deals -= 1
        original.receiver.cards.undealt.joins(:card).find_by!(cards: { value: "double" })
      else
        original.call
      end
    end
    session.play_class.(session, members.first.user)
    first = session.reload.current_player
    first.cards.active.joins(:card).find_by!(cards: { value: "double" }).play
    expect(session.reload.current_player).to eq(first)

    3.times do
      actor = session.reload.current_player
      expect(actor.possible_actions).to include("pass")
      actor.play(action: "pass")
    end

    expect(session.reload.current_player).to eq(first.next_player)
    expect(session.frames.engine_events.find_by!(action: "free_single_double")).to have_attributes(action: "free_single_double", affected_player_id: first.id)
    expect(SessionFrame::Replay.call(session.frames.order(:sequence))).to eq(SessionFrame::Snapshot.call(session))
  end

  it "rolls back a game mutation and its semantic frames if checkpoint persistence fails" do
    captain = Player::Create.!(create(:user), session: session).subject
    2.times { Player::Create.!(create(:user), session: session) }
    count = session.frames.count
    allow(SessionFrame::Snapshot).to receive(:call).and_raise("checkpoint failed")

    expect { session.play_class.(session, captain.user) }.to raise_error("checkpoint failed")
    expect(session.reload).to be_waiting
    expect(session.cards).to be_empty
    expect(session.frames.count).to eq(count)
  end

  it "retains provenance for late reports and corrections without altering digital replay" do
    captain, member = Array.new(3) { Player::Create.!(create(:user), session: session).subject }
    session.play_class.(session, captain.user)
    context = session.frames.checkpoints.last
    session.play_class.(session, captain.user)
    expect(session.reload.state).to eq("season_two")
    digital = SessionFrame::Replay.call(session.frames.order(:sequence))
    attrs = {
      "type" => "payment", "context_frame_id" => context.id, "occurred_at" => "2020-01-01T18:00:00Z",
      "data" => { "payer_id" => member.id, "payee_id" => captain.id, "amount" => 18 }
    }
    expect { SessionFrame::Observe.call(session, member.user, attrs) }.to raise_error(ActiveRecord::RecordNotFound)
    report = SessionFrame::Observe.call(session, captain.user, attrs)
    correction = SessionFrame::Observe.call(session, captain.user, attrs.merge(
      "corrects_frame_id" => report.id, "data" => attrs["data"].merge("amount" => 20)
    ))
    expect(report.reload.payload.fetch("amount")).to eq(18)
    expect(report.occurred_at).to be < report.created_at
    expect(report).to have_attributes(state: "season_one", context_frame_id: context.id)
    expect(correction).to have_attributes(kind: "correction", acting_player_id: captain.id, corrects_frame_id: report.id)
    ordered = session.frames.order(:sequence)
    expect(SessionFrame::Replay.call(ordered)).to eq(digital)
    expect(SessionFrame::Tabletop.call(ordered)).to eq(coverage: "incomplete", observations: [ correction ])
    expect(SessionFrame::Tabletop.call(ordered, through: report.sequence).fetch(:observations)).to eq([ report ])
    expect { report.update!(action: "tampered") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect {
      SessionFrame.transaction(requires_new: true) { SessionFrame.where(id: report.id).delete_all }
    }.to raise_error(ActiveRecord::StatementInvalid, /append-only/)
  end

  it "accepts game-specific auction and round-score observations without treating a missing report as a zero" do
    captain, buyer = Array.new(3) { Player::Create.!(create(:user), session: session).subject }
    session.play_class.(session, captain.user)
    card = session.reload.current_player.cards.active.first
    attrs = {
      "type" => "auction_result", "context_frame_id" => session.frames.checkpoints.last.id,
      "data" => { "card_id" => card.id, "buyer_id" => buyer.id, "winning_bid" => 0 }
    }

    expect { SessionFrame::Observe.call(session, captain.user, attrs) }
      .to raise_error(SessionFrame::Record::InvalidAction, /already played/)
    card.play
    context = session.frames.checkpoints.last
    auction = SessionFrame::Observe.call(session, captain.user, attrs.merge("context_frame_id" => context.id))
    score = SessionFrame::Observe.call(session, captain.user,
      "type" => "round_score", "context_frame_id" => context.id,
      "data" => { "player_id" => buyer.id, "score" => 35 })

    expect(auction.payload.fetch("winning_bid")).to eq(0)
    expect(score.payload.fetch("score")).to eq(35)
    expect(buyer.reload.score).to be_nil
    expect(SessionFrame::Tabletop.call(session.frames.order(:sequence))).to eq(
      coverage: "incomplete", observations: [ auction, score ]
    )
  end

  it "moves the captain role when someone leaves a waiting table" do
    first, second = Array.new(2) { Player::Create.!(create(:user), session: session).subject }
    first.leave_session
    first.rejoin_session
    expect(first.reload).not_to be_table_captain
    expect(second.reload).to be_table_captain
    expect(SessionFrame::Replay.call(session.frames.order(:sequence))).to eq(SessionFrame::Snapshot.call(session))
  end

  it "does not make up replay data for a pre-checkpoint session" do
    archived = game.sessions.create!(uid: "old-session", state: "completed", completed_at: Time.current)
    archived.frames.create!(action: "completed", subject: archived, state: "completed")
    expect(archived).not_to be_replayable
    expect { SessionFrame::Replay.call(archived.frames) }.to raise_error(SessionFrame::Replay::Unavailable)
    expect(archived.transition_actions).to eq([ "completed" ])
  end
end
