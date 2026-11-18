require "rails_helper"

RSpec.describe "Session access", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:game) { create(:game, :cards) }
  let(:member) { create(:user) }
  let(:session) { GameSession::Create.!(game).subject }
  let!(:player) { Player::Create.!(member, session: session).subject }

  def start
    game.play_class.(session, member)
    game.play_class.(session, member)
  end

  it "requires authentication before reading or mutating a session" do
    get game_session_path(session.uid), as: :json
    expect(response).to have_http_status(:unauthorized)
    post players_path, params: { uid: session.uid }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "scopes reads and mutations to a session member and their own cards and player" do
    start
    sign_in create(:user)
    get game_session_path(session.uid), as: :json
    expect(response).to have_http_status(:not_found)
    patch player_path(player), params: { player_action: "leave_session" }, as: :json
    expect(response).to have_http_status(:not_found)
    patch session_card_path(player.cards.active.first), params: { card_action: "play" }, as: :json
    expect(response).to have_http_status(:not_found)
    post session_observations_path(session.uid), params: { observation: { type: "payment" } }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "rejects a member accessing the session through another game's host" do
    create(:game, key: "modern_art", slug: "modernart")
    host! "modernart.example.com"
    sign_in member

    get game_session_path(session.uid), as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "keeps start authority with the captain" do
    other = create(:user)
    Player::Create.!(other, session: session)
    sign_in other

    expect {
      patch game_session_path(session.uid), as: :json
    }.not_to change { session.frames.count }
    expect(response).to have_http_status(:not_found)
    expect(session.reload).to be_waiting
  end

  it "returns the member's cards without exposing checkpoints or another hand" do
    other = Player::Create.!(create(:user), session: session).subject
    start
    sign_in member
    get game_session_path(session.uid), as: :json
    expect(response).to have_http_status(:ok)
    state = response.parsed_body.dig("content", "session")
    expect(state["players"].find { |row| row["id"] == player.id }.fetch("activeCards").size).to eq(4)
    expect(state["players"].find { |row| row["id"] == other.id }).not_to have_key("activeCards")
    expect(state.keys).not_to include("frames", "checkpoints")
    expect(response.headers["Cache-Control"]).to eq("no-store")
  end
end
