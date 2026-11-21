require "rails_helper"

RSpec.describe "Historical user administration", type: :request do
  let!(:owner) { create(:user, id: 1, username: "jim") }
  let!(:profile) { create(:user, id: 2, username: "archive-user") }
  let(:provider) { instance_double(CanonicalAuth) }
  let(:issuer) { "https://auth.harvj.com" }
  let(:owner_subject) { "642a708a-7eae-44a6-8dfa-8911d40b3c6f" }
  let(:owner_evidence) { "RG-PRODUCTION-HISTORICAL-OWNER-FIXTURE" }
  let!(:identity) do
    ReconcileAuthIdentity.call(profile: owner, issuer: issuer, subject: owner_subject,
      evidence: owner_evidence, operation: "link")
  end

  before do
    host! HistoricalUserAdministration::HOST
    allow(HistoricalUserAdministration).to receive_messages(enabled?: true, owner_subject: owner_subject, owner_evidence: owner_evidence)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    create(:game, :modern_art)
  end

  def oidc_login(identity, status: :found)
    stub_oidc_journey(provider, identity)
    get "/login"
    get "/auth/callback", params: { state: "fixture", code: "fixture" }
    expect(response).to have_http_status(status)
  end

  it "signs the attested owner in through the production admin entry point" do
    stub_oidc_journey(provider, identity, destination: "https://auth.harvj.com/authorize")

    get historical_admin_auth_path
    expect(response).to redirect_to("https://auth.harvj.com/authorize")
    get "/auth/callback", params: { state: "fixture", code: "fixture" }
    expect(response).to redirect_to(historical_users_path)
    get historical_users_path
    expect(response).to have_http_status(:ok)
    delete historical_admin_logout_path
    get historical_users_path
    expect(response).to have_http_status(:not_found)
  end

  it "shows the complete recovery roster, including profiles without players, and keeps other users out" do
    HistoricalUserAdministration::PROFILE_IDS.excluding(owner.id, profile.id).each { |id| create(:user, id: id) }
    create(:user, id: 12, username: "non-archive-gap")
    create(:user, id: 30, dummy: true, username: "stage-dummy")
    game = Game.find_by!(key: "modern_art")
    session = GameSession::Create.!(game).subject
    seat = Player::Create.!(owner, session: session).subject
    seat.leave_session
    experiment = GameSession::Create.!(game, experimental: true, experiment_owner: owner).subject
    Player::Create.!(owner, session: experiment)

    oidc_login(identity)
    get historical_users_path
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    rows = Nokogiri::HTML(response.body).css("tbody tr")
    expect(rows.map { |row| row.at_css("td").text.to_i }).to eq(HistoricalUserAdministration::PROFILE_IDS)
    expect(rows.first.at_css("th").text).to include("jim")
    expect(rows.first.css("td").map { |cell| cell.text.squish }).to eq([ "1", "1 Modern Art · 1", "Verified link", "None" ])
    expect(rows[1].at_css("th").text).to include("archive-user")
    expect(rows[1].css("td").map { |cell| cell.text.squish }).to eq([ "2", "0", "Unlinked", "None" ])

    get historical_user_path(owner.id)
    expect(response.body).to include(identity.evidence_reference)
    expect(response.body).not_to include(owner_subject, "Save proposal")
    get historical_user_path(12)
    expect(response).to have_http_status(:not_found)
  end

  it "saves an email, confirms it separately, and resets confirmation after an edit without sending or linking" do
    oidc_login(identity)
    expect do
      patch historical_user_path(profile.id), params: { proposed_email: "  Example@example.test  ", revision: "new" }
      expect(response).to redirect_to(historical_user_path(profile.id))
      claim = HistoricalUserClaim.find_by!(user: profile)
      expect(claim.proposed_email).to eq("Example@example.test")
      expect(claim.status).to eq(:proposed)
      expect(claim.proposed_by).to eq(owner)

      get historical_user_path(profile.id)
      form = Nokogiri::HTML(response.body).at_css("form[action$='/prepare']")
      expect(form.at_css("input[type=checkbox][name=confirm][required]")).to be_present

      post prepare_historical_user_path(profile.id), params: { revision: claim.lock_version.to_s }
      expect(response).to have_http_status(:bad_request)
      expect(claim.reload.status).to eq(:proposed)

      post prepare_historical_user_path(profile.id), params: { revision: claim.lock_version.to_s, confirm: "1" }
      expect(response).to redirect_to(historical_user_path(profile.id))
      expect(claim.reload.status).to eq(:prepared)
      expect(claim.confirmed_by).to eq(owner)
      expect(claim.attributes.values_at("issued_at", "accepted_at", "expires_at", "auth_invitation_reference")).to all(be_nil)

      patch historical_user_path(profile.id), params: { proposed_email: "updated@example.test", revision: claim.lock_version.to_s }
      expect(response).to redirect_to(historical_user_path(profile.id))
      expect(claim.reload.status).to eq(:proposed)

      post prepare_historical_user_path(profile.id), params: { revision: "0", confirm: "1" }
      expect(response).to have_http_status(:conflict)
      expect(claim.reload.status).to eq(:proposed)
      expect(profile.reload.auth_identity).to be_nil
    end.not_to change(AuthIdentityDecision, :count)
    expect(owner.reload.auth_identity).to eq(identity)
  end

  it "rejects invalid addresses and proposals for previously linked profiles" do
    oidc_login(identity)
    patch historical_user_path(profile.id), params: { proposed_email: "invalid address", revision: "new" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(HistoricalUserClaim.count).to eq(0)

    [ owner, profile ].each do |person|
      unless person == owner
        AuthIdentity.create!(user: person, issuer: issuer, subject: "other-subject", evidence_reference: "fixture", revoked_at: Time.current)
      end
      patch historical_user_path(person.id), params: { proposed_email: "existing@example.test", revision: "new" }
      expect(response).to have_http_status(:conflict)
    end
    expect(HistoricalUserClaim.count).to eq(0)
  end

  it "denies anonymous, non-owner, expired, and wrong-host requests" do
    get historical_users_path
    expect(response).to have_http_status(:not_found)
    other = AuthIdentity.create!(user: profile, issuer: issuer, subject: "other-subject", evidence_reference: "fixture")
    oidc_login(other, status: :unauthorized)
    get historical_users_path
    expect(response).to have_http_status(:not_found)
    post prepare_historical_user_path(profile.id), params: { confirm: "1", revision: "new" }
    expect(response).to have_http_status(:not_found)

    oidc_login(identity)
    host! ModernArtStaging::GAME_HOST
    get historical_users_path
    expect(response).to have_http_status(:not_found)
    host! HistoricalUserAdministration::HOST
    AuthLogin.where(auth_identity: identity).update_all(expires_at: 1.minute.ago)
    get historical_users_path
    expect(response).to have_http_status(:not_found)
  end

  it "requires audited production evidence even for the expected owner subject" do
    oidc_login(identity)
    allow(HistoricalUserAdministration).to receive(:owner_evidence).and_return("different-attestation")
    get historical_users_path
    expect(response).to have_http_status(:not_found)
    oidc_login(identity, status: :unauthorized)
    expect(HistoricalUserClaim.count).to eq(0)
  end

  it "keeps staging administration unavailable even when the production switch is requested" do
    oidc_login(identity)
    allow(ModernArtStaging).to receive(:enabled?).and_return(true)
    get historical_users_path
    expect(response).to have_http_status(:not_found)
    post prepare_historical_user_path(profile.id), params: { confirm: "1", revision: "new" }
    expect(response).to have_http_status(:not_found)
    expect(HistoricalUserClaim.count).to eq(0)
  end

  it "denies a scoped dummy browser and applies CSRF protection to proposal changes" do
    table = GameSession::Create.!(Game.find_by!(key: "modern_art"), experimental: true, experiment_owner: owner).subject
    dummy = Player::Create.!(create(:user, id: 30, dummy: true), session: table).subject
    code = dummy.create_dummy_access!(expires_at: Time.current).issue!
    allow(ExperimentalAccess).to receive(:enabled?).and_return(true)
    post dummy_login_path, params: { dummy_credential: code }
    expect(response).to have_http_status(:see_other)
    get historical_users_path
    expect(response).to have_http_status(:not_found)

    delete dummy_logout_path
    oidc_login(identity)
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get historical_user_path(profile.id)
    expect(response).to have_http_status(:ok)
    token = Nokogiri::HTML(response.body).at_css(%(form[action="#{historical_user_path(profile.id)}"] input[name=authenticity_token]))["value"]
    proposal = { proposed_email: "example@example.test", revision: "new" }
    patch historical_user_path(profile.id), params: proposal
    expect(response).to have_http_status(:not_found)
    expect(HistoricalUserClaim.count).to eq(0)

    patch historical_user_path(profile.id), params: proposal.merge(authenticity_token: token)
    expect(response).to have_http_status(:see_other)
    expect(HistoricalUserClaim.find_by!(user: profile).status).to eq(:proposed)
  ensure
    ActionController::Base.allow_forgery_protection = protection unless protection.nil?
  end
end
