require "rails_helper"

RSpec.describe "Session replay", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:game) { create(:game, :modern_art) }
  let(:table) { GameSession::Create.!(game).subject }
  let(:members) { create_list(:user, 3) }

  def frame(sequence)
    get session_replay_path(table.uid), params: { frame: sequence }, as: :json
    response.parsed_body
  end

  it "projects the requested checkpoints using the recorded state and limits hidden cards to the viewer" do
    members.each { |user| Player::Create.!(user, session: table) }
    table.play_class.(table, members.first)
    checkpoint = table.frames.checkpoints.last
    own = table.players.find_by!(user: members.first)
    card = table.reload.current_player.cards.active.find(&:playable?)
    card.play
    original = SessionFrame::Replay.call(table.frames.order(:sequence), through: checkpoint.sequence)
    table.update_column(:state, "completed")
    sign_in members.first

    first = frame(1)
    expect(first).to include("phase" => "waiting", "players" => [])
    started = frame(checkpoint.sequence)
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(started["phase"]).to eq(original.fetch("session").fetch("state"))
    expect(started["played"]).to be_empty
    expect(started["players"].find { |seat| seat["id"] == own.id }["hand"].size).to eq(10)
    expect(started["players"].reject { |seat| seat["id"] == own.id }.pluck("hand")).to eq([ nil, nil ])
    expect(started.to_json).not_to include("definition", "session_deck_id", "payload")
    expect(frame(table.frames.last.sequence)["played"].pluck("id")).to include(card.id)
    expect(frame(checkpoint.sequence)).to eq(started)
  end

  it "shows observed and superseded reports only once they exist at the selected cursor" do
    members.each { |user| Player::Create.!(user, session: table) }
    table.play_class.(table, members.first)
    context = table.frames.checkpoints.last
    report = {
      "type" => "payment", "context_frame_id" => context.id,
      "occurred_at" => "2026-01-15T14:17:00Z",
      "data" => { "payer_id" => table.players.find_by!(user: members.first).id,
        "payee_id" => table.players.find_by!(user: members.last).id, "amount" => 12 }
    }
    first = SessionFrame::Observe.call(table, members.first, report)
    correction = SessionFrame::Observe.call(table, members.first,
      report.merge("corrects_frame_id" => first.id, "data" => report["data"].merge("amount" => 14)))
    sign_in members.first

    expect(frame(context.sequence)["observations"]).to be_empty
    expect(frame(first.sequence)["observations"].first).to include("kind" => "observation", "superseded" => false)
    reports = frame(correction.sequence)["observations"]
    expect(reports.map { |entry| entry["data"]["amount"] }).to eq([ 12, 14 ])
    expect(reports.first).to include("superseded" => true, "actor" => members.first.name)
    expect(reports.last).to include("kind" => "correction", "corrects" => first.sequence,
      "context" => context.sequence, "occurredAt" => "2026-01-15T14:17:00.000000Z")
  end

  it "denies nonparticipants even when an ordinary table is waiting and joinable" do
    sign_in members.first
    get session_replay_path(table.uid), as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "describes legacy sessions to authorized members and rejects oversized cursors" do
    Player::Create.!(members.first, session: table)
    legacy = game.sessions.create!(uid: "legacy-replay", state: "completed")
    legacy.all_players.create!(user: members.first, game_id: game.id, action_phase: "idle")
    sign_in members.first

    get session_replay_path(legacy.uid)
    expect(response.body).to include("Replay unavailable")
    get session_replay_path(legacy.uid), as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    get session_replay_path(table.uid), params: { frame: 1_000_000 }, as: :json
    expect(response).to have_http_status(:bad_request)
  end
end
