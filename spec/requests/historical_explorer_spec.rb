require "rails_helper"

RSpec.describe "Public Modern Art historical explorer", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:game) { create(:game, :modern_art) }
  let(:player) { create(:user, name: "Approved player", username: "private-handle") }
  let(:table) { historical_table("approved-table", player) }

  def historical_table(uid, member, game_record: game, **attributes)
    game_record.sessions.create!({ uid: uid, state: "completed", completed_at: Time.current }.merge(attributes)).tap do |session|
      session.all_players.create!(user: member, game_id: game_record.id, score: 543, winner: true, turn_order: 1, action_phase: "idle")
    end
  end

  def board
    script = Nokogiri::HTML(response.body).at_css("#practice-table-data").text
    JSON.parse(script).fetch("board")
  end

  def allow_fields(entries)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_HISTORICAL_EXPLORER").and_return("1")
    allow(ENV).to receive(:fetch).with("REMOTE_GAMING_PUBLIC_HISTORICAL_SESSIONS", "{}").and_return(entries.to_json)
  end

  before { host! HistoricalExplorer::HOST }

  it "uses a narrow public projection regardless of browser identity or query parameters" do
    seat = table.players.first
    deck = table.decks.create!(key: "default")
    definitions = game.cards.limit(4).to_a
    definitions.each_with_index do |definition, index|
      details = [
        { player: seat, dealt_at: 1.day.ago },
        { player: seat, dealt_at: 1.day.ago, played_at: 1.hour.ago },
        { player: seat, dealt_at: 1.day.ago, discarded_at: 1.hour.ago },
        {}
      ].fetch(index)
      deck.cards.create!(session: table, card: definition, **details)
    end
    observed = table.frames.create!(subject: table, action: "payment", kind: "observation", sequence: 1,
      payload: { "note" => "private-payment-detail" })
    table.frames.create!(subject: table, action: "payment", kind: "correction", sequence: 2, corrects_frame: observed,
      payload: { "amount" => 842_951 })
    allow_fields(table.uid => HistoricalExplorer::FIELDS)
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Approved player", "$543k", historical_explorer_session_path(table.uid))
    expect(response.body).not_to include("Create New", "practice tables")

    get historical_explorer_session_path(table.uid), params: { frame: 1, player: seat.id }
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(response.body).not_to include("private-address", "private-handle", "session_deck_id", "user_id", "private-payment-detail", "842951")
    expect(board).to include("publicHistory" => true, "concluded" => true, "completeReplay" => false, "legal" => {})
    expect(board.fetch("players").first).to include("seat" => 1, "name" => "Approved player", "finalCash" => 543)
    expect(board.fetch("players").first.fetch("hand").pluck("name", "value")).to eq(
      [ [ definitions[0].name.titleize, definitions[0].value.titleize ] ])
    expect(board.fetch("played").pluck("name", "value")).to eq([ [ definitions[1].name.titleize, definitions[1].value.titleize ] ])
    expect(board.fetch("actionHistory")).to eq([
      { "frame" => 1, "description" => "Payment" }, { "frame" => 2, "description" => "Correction · Payment" }
    ])
    public_board = board
    sign_in player
    get historical_explorer_session_path(table.uid)
    expect(board).to eq(public_board)
    get historical_explorer_session_path(table.uid), as: :json
    expect(response).to have_http_status(:not_acceptable)
  end

  it "excludes unapproved, unfinished, private, synthetic-human and other-game tables and honors field approvals" do
    active = historical_table("unfinished", player, state: "season_four")
    experimental = historical_table("private-table", player, experimental: true, experiment_owner: player)
    other = historical_table("other-game", player, game_record: create(:game, key: "pandemic", slug: "pandemic", name: "Pandemic"))
    digital = historical_table("digital-table", player)
    ModernArtPracticeTable.open!(player, game, human_session: digital)
    hidden = historical_table("not-approved", player)
    allow_fields([ table, active, experimental, other, digital ].to_h { |record| [ record.uid, [] ] })
    get historical_explorer_path
    expect(response.body).to include(historical_explorer_session_path(table.uid))
    listing = response.body
    [ active, experimental, other, digital, hidden ].each do |record|
      expect(listing).not_to include(historical_explorer_session_path(record.uid))
      get historical_explorer_session_path(record.uid)
      expect(response).to have_http_status(:not_found)
    end
    get historical_explorer_session_path(table.uid)
    expect(board.fetch("players").first).to include("name" => "Player 1", "hand" => nil, "finalCash" => nil)
    expect(board.fetch("played")).to be_empty
    expect(response.body).not_to include("Approved player")
    host! "gaming.harvj.com"
    get historical_explorer_session_path(table.uid)
    expect(response).to have_http_status(:not_found)
  end

  it "rejects modifications to explorer routes and fails closed on a malformed approval list" do
    allow_fields(table.uid => HistoricalExplorer::FIELDS)
    expect do
      [ :post, :patch, :delete ].each do |verb|
        public_send(verb, historical_explorer_session_path(table.uid), params: { score: 999 })
        expect(response).to have_http_status(:not_found)
      end
    end.not_to change { table.players.first.reload.score }
    allow_fields(table.uid => [ "unsupported" ])
    get historical_explorer_session_path(table.uid)
    expect(response).to have_http_status(:not_found)
  end
end
