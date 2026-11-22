require "rails_helper"

RSpec.describe "Retired private experiments", type: :request do
  it "keeps an existing experiment and its fork readable while rejecting creation and management" do
    game = create(:game, :modern_art)
    owner = create(:user)
    outsider = create(:user)
    stub_const("ModernArtStaging::OWNER_PROFILE_ID", owner.id)
    source = GameSession::Create.!(game, experimental: true, experiment_owner: owner).subject
    Player::Create.!(owner, session: source)
    fork = source.frames.last
    branch = GameSession::Create.!(game, experimental: true, experiment_owner: owner,
      parent_session: source, fork_frame: fork, branch_rules_version: 1).subject
    Player::Create.!(owner, session: branch)
    issuer = "https://auth.harvj.com"
    identity = AuthIdentity.create!(user: owner, issuer: issuer, subject: "owner", evidence_reference: "fixture")
    provider = instance_double(CanonicalAuth)
    allow(ModernArtStaging).to receive_messages(enabled?: true, owner_subject: identity.subject)
    allow(CanonicalAuth).to receive_messages(enabled?: true, new: provider)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_CLIENT_ID").and_return("practice")
    stub_oidc_journey(provider, identity)
    host! ModernArtStaging::GAME_HOST
    get "/login"
    get "/auth/callback", params: { state: "fixture", code: "fixture" }

    get game_session_path(branch.uid)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Add dummy player", "Manage staging seats")
    get session_replay_path(branch.uid)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(session_replay_path(source.uid, frame: fork.sequence))
    expect(response.body).not_to include("branchPath", "branchToken")
    lobby = Representers::Game.(game, viewer: owner)
    expect(lobby).not_to have_key(:experiments)
    expect(lobby.fetch(:sessions).pluck(:uid)).not_to include(source.uid, branch.uid)
    expect(branch.can_view?(outsider)).to be(false)

    historical_frames = SessionFrame.where(game_session_id: [ source.id, branch.id ]).order(:id).map(&:attributes)
    expect do
      post game_sessions_path, params: { game_key: game.key, experimental: "1" }
      expect(response).to have_http_status(:forbidden)
      post "/s/#{source.uid}/branches", params: { frame: fork.sequence }
      expect(response).to have_http_status(:not_found)
      post session_dummies_path(branch.uid)
      expect(response).to have_http_status(:not_found)
      patch game_session_path(branch.uid), as: :json
      expect(response).to have_http_status(:not_found)
    end.not_to change(GameSession, :count)
    expect(SessionFrame.where(game_session_id: [ source.id, branch.id ]).order(:id).map(&:attributes)).to eq(historical_frames)
  end
end
