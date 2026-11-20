require "rails_helper"

RSpec.describe "Private experiments", type: :request do
  let!(:game) { create(:game, :modern_art) }
  let(:owner) { create(:user) }
  let(:outsider) { create(:user) }
  let(:oidc) { instance_double(CanonicalAuth) }

  before do
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    allow(ExperimentalAccess).to receive(:enabled?).and_return(true)
    allow(CanonicalAuth).to receive(:new).and_return(oidc)
  end

  def login(browser, person)
    identity = AuthIdentity.create!(user: person, subject: person.username,
      issuer: ENV["REMOTE_GAMING_OIDC_ISSUER"], evidence_reference: "fixture")
    allow(oidc).to receive(:authenticate).with(nil, state: "fixture", code: person.username).and_return([ identity, CanonicalAuth::PASSWORD ])
    browser.get("/auth/callback", params: { state: "fixture", code: person.username })
  end

  def issue(browser, table)
    browser.post(session_dummies_path(table.uid))
    expect(browser.response).to have_http_status(:created)
    expect(browser.response.headers["Cache-Control"]).to eq("no-store")
    Nokogiri::HTML(browser.response.body).at_css("#dummy-credential").text
  end

  around do |example|
    previous = ENV["REMOTE_GAMING_OIDC_ISSUER"]
    ENV["REMOTE_GAMING_OIDC_ISSUER"] = "https://auth.example.test"
    example.run
  ensure
    ENV["REMOTE_GAMING_OIDC_ISSUER"] = previous
  end

  it "isolates two browser seats and supports credential rotation, logout, and revocation" do
    login(self, owner)
    post game_sessions_path, params: { game_key: "modern_art", experimental: "1" }
    table = GameSession.find_by!(experiment_owner: owner)
    expect(response).to redirect_to(game_session_path(table.uid))
    expect(table.players.first.user).to eq(owner)
    first_credential = issue(self, table)
    second_credential = issue(self, table)
    expect(table.reload.players.size).to eq(3)

    first = ActionDispatch::Integration::Session.new(Rails.application)
    second = ActionDispatch::Integration::Session.new(Rails.application)
    first.post(dummy_login_path, params: { dummy_credential: first_credential })
    second.post(dummy_login_path, params: { dummy_credential: second_credential })
    expect(first.response).to have_http_status(:see_other)
    expect(URI(first.response.location).path).to eq(game_session_path(table.uid))
    expect(second.response).to have_http_status(:see_other)
    expect(URI(second.response.location).path).to eq(game_session_path(table.uid))
    expect(first.response.location).not_to include(first_credential)
    retry_browser = ActionDispatch::Integration::Session.new(Rails.application)
    retry_browser.post(dummy_login_path, params: { dummy_credential: first_credential })
    expect(retry_browser.response).to have_http_status(:not_found)

    uninvited = ActionDispatch::Integration::Session.new(Rails.application)
    login(uninvited, outsider)
    uninvited.get(game_session_path(table.uid), as: :json)
    expect(uninvited.response).to have_http_status(:not_found)
    uninvited.post(players_path, params: { uid: table.uid }, as: :json)
    expect(uninvited.response).to have_http_status(:not_found)

    ordinary = GameSession::Create.!(game).subject
    first.get(game_session_path(ordinary.uid), as: :json)
    expect(first.response).to have_http_status(:not_found)
    first.get(user_path(owner))
    expect(first.response).to have_http_status(:not_found)
    first.post(session_dummies_path(table.uid))
    expect(first.response).to have_http_status(:not_found)
    first.patch(game_session_path(table.uid), as: :json)
    expect(first.response).to have_http_status(:not_found)
    first.post(session_observations_path(table.uid), params: { observation: { type: "payment" } }, as: :json)
    expect(first.response).to have_http_status(:not_found)
    first.post("/auth/start")
    expect(first.response).to have_http_status(:not_found)
    first.patch user_config_path(owner), params: { config: { show_all_badges: true } }, as: :json
    expect(first.response).to have_http_status(:not_found)

    dummy = table.players.joins(:dummy_access).order(:id).first
    patch game_session_path(table.uid), as: :json
    expect(response).to have_http_status(:ok)
    first.get(game_session_path(table.uid), as: :json)
    expect(first.response).to have_http_status(:ok)
    roster = first.response.parsed_body.dig("content", "session", "players")
    expect(roster.select { |row| row.key?("activeCards") }.pluck("id")).to eq([ dummy.id ])
    other = table.players.where.not(id: dummy.id).first
    first.patch session_card_path(other.cards.active.first), params: { card_action: "play" }, as: :json
    expect(first.response).to have_http_status(:not_found)
    expect(Representers::Game.(game, viewer: owner).fetch(:sessions)).to be_empty
    expect(Representers::Game.(game, viewer: owner).fetch(:experiments).pluck(:uid)).to eq([ table.uid ])
    expect(Query::Users.(:game_stats, user_id: owner.id).first.play_count).to eq(0)
    expect(table.frames.where(action: "player_created").pluck(:actor_kind).uniq).to eq([ "person" ])
    expect(SessionFrame::Replay.call(table.frames.order(:sequence))).to eq(SessionFrame::Snapshot.call(table.reload))

    post rotate_session_dummy_path(table.uid, dummy.id)
    expect(response).to have_http_status(:ok)
    new_credential = Nokogiri::HTML(response.body).at_css("#dummy-credential").text
    first.get(game_session_path(table.uid), as: :json)
    expect(first.response).to have_http_status(:not_found)
    first.post(dummy_login_path, params: { dummy_credential: new_credential })
    expect(first.response).to have_http_status(:see_other)
    expect(URI(first.response.location).path).to eq(game_session_path(table.uid))
    delete session_dummy_path(table.uid, dummy.id)
    first.get(game_session_path(table.uid), as: :json)
    expect(first.response).to have_http_status(:not_found)
    second.get(game_session_path(table.uid), as: :json)
    expect(second.response).to have_http_status(:ok)
    second.delete(dummy_logout_path)
    expect(second.response).to have_http_status(:see_other)
    expect(URI(second.response.location).path).to eq(dummy_login_path)
  end
  it "rejects expired credentials without creating browser access" do
    login(self, owner)
    post game_sessions_path, params: { game_key: "modern_art", experimental: "1" }
    table = GameSession.find_by!(experiment_owner: owner)
    credential = issue(self, table)
    table.players.joins(:dummy_access).first.dummy_access.update!(expires_at: 1.second.ago)
    browser = ActionDispatch::Integration::Session.new(Rails.application)
    browser.post(dummy_login_path, params: { dummy_credential: credential })
    expect(browser.response).to have_http_status(:not_found)
  end
end
