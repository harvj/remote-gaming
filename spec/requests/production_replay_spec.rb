require "rails_helper"
require "open3"

RSpec.describe "Production replay route boundaries", type: :request do
  def production_routes(enable_replay, admin: false)
    environment = {
      "RAILS_ENV" => "production",
      "DATABASE_URL" => nil,
      "SECRET_KEY_BASE_DUMMY" => "1",
      "REMOTE_GAMING_PRIVATE_STAGING" => nil,
      "REMOTE_GAMING_HISTORICAL_ADMIN" => admin ? "1" : nil,
      "REMOTE_GAMING_HISTORICAL_ADMIN_OWNER_EVIDENCE" => admin ? "RG-PRODUCTION-HISTORICAL-OWNER-FIXTURE" : nil,
      "REMOTE_GAMING_HISTORICAL_ADMIN_OWNER_SUBJECT" => admin ? "11111111-2222-4333-8444-555555555555" : nil,
      "REMOTE_GAMING_PRODUCTION_REPLAY" => enable_replay ? "1" : nil,
      "REMOTE_GAMING_OIDC_ISSUER" => "https://auth.harvj.com",
      "REMOTE_GAMING_OIDC_CLIENT_ID" => "fixture",
      "REMOTE_GAMING_OIDC_CLIENT_SECRET" => "fixture",
      "REMOTE_GAMING_OIDC_REDIRECT_URI" => "https://gaming.harvj.com/auth/callback"
    }
    output, status = Open3.capture2e(environment, RbConfig.ruby, "bin/rails", "routes")
    expect(status).to be_success, output
    output
  end

  it "mounts only authenticated read-only replay when independently enabled in production" do
    routes = production_routes(true)
    expect(routes).to match(/GET +\/s\/:uid\/replay.*session_replays#show/)
    expect(routes).to match(/GET +\/replay.*session_replays#index/)
    expect(routes).not_to match(/session_branches#|dummy_accesses#|game_sessions#|session_cards#|players#|historical_users#|\/cable/)
  end

  it "leaves the public directory's production routes alone by default" do
    expect(production_routes(false)).not_to match(/session_replays#|session_branches#|dummy_accesses#|game_sessions#|historical_users#|modern_art_practice_tables#/)
  end

  it "mounts owner administration independently of replay and gameplay" do
    routes = production_routes(false, admin: true)
    expect(routes).to include("historical_users#index", "historical_users#prepare", "auth#start_admin", "auth#callback")
    expect(routes).not_to match(/session_replays#|session_branches#|dummy_accesses#|game_sessions#|\/cable/)
  end

  it "rejects direct experiment, dummy-management, and active-branch requests outside staging" do
    game = create(:game, :modern_art)
    captain = create(:user)
    table = GameSession::Create.!(game).subject
    Player::Create.!(captain, session: table)
    table.update_column(:state, "season_one")
    issuer = "https://auth.example.test"
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    allow(ModernArtStaging).to receive(:enabled?).and_return(false)
    identity = AuthIdentity.create!(user: captain, issuer: issuer, subject: "fixture", evidence_reference: "fixture")
    provider = instance_double(CanonicalAuth)
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    stub_oidc_journey(provider, identity, assurance: CanonicalAuth::MFA)
    get "/login"
    get "/auth/callback", params: { state: "fixture", code: "fixture" }

    expect do
      post session_branches_path(table.uid), params: { frame: 1 }
      expect(response).to have_http_status(:not_found)
      post session_dummies_path(table.uid)
      expect(response).to have_http_status(:not_found)
      get dummy_login_path
      expect(response).to have_http_status(:not_found)
      post game_sessions_path, params: { game_key: game.key, experimental: "1" }
      expect(response).to have_http_status(:forbidden)
    end.not_to change(GameSession, :count)
    get session_replay_path(table.uid), as: :json
    expect(response).to have_http_status(:ok)
  end
end
