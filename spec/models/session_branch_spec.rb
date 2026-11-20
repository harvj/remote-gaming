require "rails_helper"

RSpec.describe SessionFrame::Branch do
  let(:owner) { create(:user) }
  let(:game) { create(:game, :modern_art) }
  let(:table) { GameSession::Create.!(game, experimental: true, experiment_owner: owner).subject }

  before do
    allow(ExperimentalAccess).to receive(:enabled?).and_return(true)
    Player::Create.!(owner, session: table)
    2.times do
      dummy = create(:user, dummy: true)
      seat = Player::Create.!(dummy, session: table).subject
      seat.create_dummy_access!(expires_at: Time.current).issue!
    end
    table.play_class.(table, owner)
  end

  it "copies recorded orders, deals, and correction provenance and continues independently" do
    checkpoint = table.frames.last
    payer, payee = table.players.first(2)
    report = { "type" => "payment", "context_frame_id" => checkpoint.id,
      "data" => { "payer_id" => payer.id, "payee_id" => payee.id, "amount" => 10 } }
    observed = SessionFrame::Observe.call(table, owner, report)
    SessionFrame::Observe.call(table, owner, report.merge("corrects_frame_id" => observed.id,
      "data" => report["data"].merge("amount" => 12)))
    source_player = table.reload.current_player
    source_card = source_player.cards.active.find { |card| card.playable? && card.card.value != "double" }
    source_card.play
    fork = table.frames.checkpoints.last
    next_card = table.reload.current_player.cards.active.find(&:playable?)
    next_card.play
    original_snapshot = SessionFrame::Snapshot.call(table.reload)
    original_frames = table.frames.order(:sequence).map(&:attributes)

    branch = described_class.call(table, viewer: owner, cursor: fork.sequence)
    expect(branch).to have_attributes(parent_session: table, fork_frame: fork, branch_rules_version: 1,
      experiment_owner: owner, experimental: true)
    expect(GameSession.ordinary.where(id: branch.id)).not_to exist
    expect(Representers::Game.(game, viewer: owner).fetch(:sessions).pluck(:uid)).not_to include(branch.uid)
    expect(Representers::Game.(game, viewer: owner).fetch(:experiments).pluck(:uid)).to include(branch.uid)
    expect(branch.frames.pluck(:id) & table.frames.pluck(:id)).to be_empty
    expect(branch.players.pluck(:turn_order)).to eq(table.players.pluck(:turn_order))
    expect(branch.players.map { |seat| seat.cards.dealt.order(:id).pluck(:card_id) }).to eq(
      table.players.map { |seat| seat.cards.dealt.order(:id).pluck(:card_id) })
    copied_report, copied_correction = branch.frames.observations.order(:sequence).to_a
    expect(copied_correction.corrects_frame).to eq(copied_report)
    expect(copied_report.context_frame.game_session).to eq(branch)
    expect(copied_report.payload["payer_id"]).not_to eq(payer.id)
    expect(SessionFrame::Replay.call(branch.frames.order(:sequence))).to eq(SessionFrame::Snapshot.call(branch))

    eligible = branch.current_player.cards.active.select(&:playable?)
    alternate = eligible.find { |card| card.card_id != next_card.card_id }
    expect(alternate).to be_present
    alternate.play
    expect(branch.frames.checkpoints.last.sequence).to be > fork.sequence
    expect(branch.frames.engine_events.where(action: "card_played").last.subject.card_id).to eq(alternate.card_id)
    expect(SessionFrame::Snapshot.call(table.reload)).to eq(original_snapshot)
    expect(table.frames.order(:sequence).map(&:attributes)).to eq(original_frames)
  end

  it "uses new seat identities and requires a branch-specific dummy credential" do
    fork = table.frames.checkpoints.last
    branch = described_class.call(table, viewer: owner, cursor: fork.sequence)
    original = table.players.joins(:dummy_access).first
    copied = branch.players.joins(:dummy_access).first

    expect(branch.can_replay?(original.user)).to be(false)
    expect(table.can_replay?(copied.user)).to be(false)
    expect(branch.can_replay?(copied.user)).to be(true)
    expect(copied.dummy_access.credential_digest).to be_nil
    _, ticket = DummyAccess.redeem!(copied.dummy_access.issue!)
    expect(DummyAccess.authorized(ticket).session).to eq(branch)
  end

  it "rejects intermediate events, unstarted checkpoints, unrelated owners, and disabled environments" do
    expect do
      described_class.call(table, viewer: owner, cursor: table.frames.engine_events.first.sequence)
    end.to raise_error(described_class::Unsupported)
    expect do
      described_class.call(table, viewer: owner, cursor: 1)
    end.to raise_error(described_class::Unsupported)
    expect do
      described_class.call(table, viewer: create(:user), cursor: table.frames.last.sequence)
    end.to raise_error(ActiveRecord::RecordNotFound)
    allow(ExperimentalAccess).to receive(:enabled?).and_call_original
    expect do
      described_class.call(table, viewer: owner, cursor: table.frames.last.sequence)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
