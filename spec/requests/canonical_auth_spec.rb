require "rails_helper"

RSpec.describe "Canonical Auth", type: :request do
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwks) { { "keys" => [ JWT::JWK.new(key.public_key, "auth-key").export ] } }
  let(:profile) { create(:user, username: "radio") }
  let(:issuer) { "https://auth.example.test" }
  let(:redirect_uri) { "https://www.example.com/auth/callback" }

  around do |example|
    config = {
      "REMOTE_GAMING_OIDC_ISSUER" => issuer, "REMOTE_GAMING_OIDC_CLIENT_ID" => "gaming",
      "REMOTE_GAMING_OIDC_CLIENT_SECRET" => "fixture", "REMOTE_GAMING_OIDC_REDIRECT_URI" => redirect_uri
    }
    previous = ENV.to_h.slice(*config.keys)
    ENV.update(config)
    example.run
  ensure
    config.keys.each { |key| ENV.delete(key) }
    ENV.update(previous)
  end

  before do
    allow_any_instance_of(CanonicalAuth).to receive(:provider_metadata).and_return(
      { "issuer" => issuer, "authorization_endpoint" => "#{issuer}/authorize",
        "token_endpoint" => "#{issuer}/token", "jwks_uri" => "#{issuer}/jwks" }
    )
    allow_any_instance_of(CanonicalAuth).to receive(:revoke)
  end

  def start
    post "/auth/start"
    expect(response).to have_http_status(:redirect)
    URI.decode_www_form(URI(response.location).query).to_h
  end

  def callback(authorization, shell_username: nil, **claims)
    attributes = { iss: issuer, aud: "gaming", sub: "canonical-subject", nonce: authorization.fetch("nonce"),
      iat: Time.current.to_i, exp: 5.minutes.from_now.to_i, acr: CanonicalAuth::PASSWORD }.merge(claims)
    token = JWT.encode(attributes, key, "RS256", kid: "auth-key")
    stub_token_exchange do |request|
      expect(request.request_headers["Authorization"]).to eq("Basic #{Base64.strict_encode64('gaming:fixture')}")
      form = URI.decode_www_form(request.body).to_h
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(form.fetch("code_verifier")), padding: false)
      expect(challenge).to eq(authorization.fetch("code_challenge"))
      expect(form.fetch("redirect_uri")).to eq(authorization.fetch("redirect_uri"))
      { "id_token" => token, "access_token" => "fixture-grant", "expires_in" => 300, "token_type" => "Bearer" }
    end
    allow_any_instance_of(CanonicalAuth).to receive(:fetch_json) do |_provider, uri, request|
      expect(uri.host).to eq(URI(issuer).host)
      next jwks unless uri.path == "/introspect"

      result = { "active" => true, "client_id" => "gaming" }
      if shell_username && URI.decode_www_form(request.body).to_h["application_shell_version"] == "1"
        now = Time.current.to_i
        result["application_shell"] = {
          "version" => "1", "iss" => issuer, "aud" => "gaming", "sub" => attributes.fetch(:sub),
          "grant_binding" => Digest::SHA256.hexdigest("fixture-grant"),
          "preferred_username" => shell_username, "iat" => now, "exp" => now + 30
        }
      end
      result
    end
    get "/auth/callback", params: { state: authorization.fetch("state"), code: "fixture-code" }
  end

  def stub_token_exchange(&response)
    transport = Faraday.new do |connection|
      connection.request :url_encoded
      connection.adapter :test do |stub|
        stub.post("#{issuer}/token") { |request| [ 200, {}, response.call(request) ] }
      end
    end
    allow(Rack::OAuth2).to receive(:http_client).and_return(transport)
  end

  it "authenticates a linked historical profile with password assurance and logs out locally" do
    host! "radioactivita.com"
    create(:game, key: "modern_art")
    AuthIdentity.create!(issuer: issuer, subject: "canonical-subject", user: profile, evidence_reference: "approval-123")
    expect(start.fetch("code_challenge_method")).to eq("S256")
    callback(start, shell_username: "verified_name")
    expect(response).to have_http_status(:redirect)
    expect(AuthLogin.last.auth_identity.user_id).to eq(profile.id)
    expect(AuthLogin.last.assurance).to eq(CanonicalAuth::PASSWORD)
    get "/users/radio"
    expect(response).to have_http_status(:ok)
    get "/"
    expect(response.body).to include('class="directory-apps"', 'verified_name')
    expect(response.body).not_to include('href="https://intelligence.harvj.com/"')
    expect(response.body).not_to include('class="directory-login"')
    expect(response.headers["Cache-Control"]).to eq("no-store")
    delete "/logout"
    expect(response).to have_http_status(:see_other)
    get "/"
    expect(response.body).to include('class="directory-login"')
    expect(response.body).not_to include('class="directory-apps"')
    get "/modern_art"
    expect(response).to have_http_status(:redirect)
  end

  it "preserves the approved client and a safe destination when navigation initiates Auth" do
    AuthIdentity.create!(issuer: issuer, subject: "canonical-subject", user: profile, evidence_reference: "approval-123")
    [ [ "/s/private-room/replay", "/s/private-room/replay" ], [ "//outside.example", "/" ],
      [ "/auth/callback", "/" ] ].each do |destination, expected|
      get "/auth/start", params: { return_to: destination }
      authorize = URI(response.location)
      expect(authorize.path).to eq("/authorize")
      authorization = URI.decode_www_form(authorize.query).to_h
      expect(authorization).to include("client_id" => "gaming", "redirect_uri" => redirect_uri, "code_challenge_method" => "S256")
      callback(authorization)
      expect(response).to redirect_to(expected)
      delete "/logout"
    end
  end

  it "accepts signed voluntary MFA but never links by name and rejects foreign audiences and unknown assurance" do
    callback(start, preferred_username: profile.username)
    expect(response).to have_http_status(:unauthorized)
    expect(profile.reload.auth_identity).to be_nil
    AuthIdentity.create!(issuer: issuer, subject: "canonical-subject", user: profile, evidence_reference: "approval-123")
    callback(start, acr: "other")
    expect(response).to have_http_status(:unauthorized)
    callback(start, aud: "other-client")
    expect(response).to have_http_status(:unauthorized)
    callback(start, exp: 1.minute.ago.to_i)
    expect(response).to have_http_status(:unauthorized)
    callback(start, exp: 5.minutes.from_now.to_i + 0.5)
    expect(response).to have_http_status(:unauthorized)
    callback(start, nonce: "wrong")
    expect(response).to have_http_status(:unauthorized)
    callback(start, acr: CanonicalAuth::MFA)
    expect(response).to have_http_status(:redirect)
    expect(AuthLogin.last.assurance).to eq(CanonicalAuth::MFA)
  end

  it "rejects bad state and disables legacy password login while configured" do
    start
    get "/auth/callback", params: { state: "wrong", code: "fixture-code" }
    expect(response).to have_http_status(:unauthorized)
    post "/login", params: { user: { username: "radio", password: "fixture" } }
    expect(response).to have_http_status(:not_found)
  end
  it "reuses a usable local session and fails closed when the provider invalidates the grant" do
    host! "radioactivita.com"
    AuthIdentity.create!(issuer: issuer, subject: "canonical-subject", user: profile, evidence_reference: "approval-123")
    callback(start)
    login = AuthLogin.last
    expect(login.grant_ciphertext).not_to include("fixture-grant")
    expect(login.expires_at).to be_within(2.seconds).of(5.minutes.from_now)

    expect { get "/login", params: { return_to: "/s/review" } }.not_to change(AuthLoginAttempt, :count)
    expect(response).to redirect_to("/s/review")

    allow_any_instance_of(CanonicalAuth).to receive(:active_access_token?).and_return(false)
    get "/s/review", as: :json
    expect(response).to have_http_status(:unauthorized)
    get "/"
    expect(response).to have_http_status(:ok)
    delete "/logout"
    expect(response).to have_http_status(:see_other)
    expect(AuthLogin.exists?(login.id)).to be(false)
  end

  it "consumes only the matched browser transaction and rejects replays, expired state and background starts" do
    AuthIdentity.create!(issuer: issuer, subject: "canonical-subject", user: profile, evidence_reference: "approval-123")
    expect { get "/login", headers: { "Sec-Purpose" => "prefetch" } }.not_to change(AuthLoginAttempt, :count)
    expect(response).to have_http_status(:bad_request)
    first = start
    second = start
    other = ActionDispatch::Integration::Session.new(Rails.application)
    other.get("/auth/callback", params: { state: first.fetch("state"), code: "fixture" })
    expect(other.response).to have_http_status(:unauthorized)
    expect(AuthLoginAttempt.count).to eq(2)

    get "/auth/callback?state=#{first.fetch("state")}&state=#{second.fetch("state")}&code=fixture"
    expect(response).to have_http_status(:unauthorized)
    get "/auth/callback", params: { state: first.fetch("state"), error: "access_denied" }
    expect(response).to have_http_status(:unauthorized)
    expect(AuthLoginAttempt.count).to eq(1)
    callback(first)
    expect(response).to have_http_status(:unauthorized)

    AuthLoginAttempt.update_all(expires_at: 1.second.ago)
    callback(second)
    expect(response).to have_http_status(:unauthorized)
    expect(AuthLogin.count).to eq(0)
  end

  it "leaves the public directory usable and renders an explicit retry even when discovery is unavailable" do
    host! "radioactivita.com"
    allow_any_instance_of(CanonicalAuth).to receive(:provider_metadata).and_raise(CanonicalAuth::InvalidLogin)
    get "/login"
    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers["Location"]).to be_nil
    expect(response.body).to include("Try signing in again")
    get "/"
    expect(response).to have_http_status(:ok)
    expect(AuthLoginAttempt.count).to eq(0)
  end

  it "rejects an incomplete token response without opening a local login" do
    authorization = start
    stub_token_exchange { { "id_token" => [] } }

    expect do
      get "/auth/callback", params: { state: authorization.fetch("state"), code: "fixture-code" }
    end.not_to change(AuthLogin, :count)
    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["Cache-Control"]).to eq("no-store")
  end
  it "links and revokes the original jim profile without touching its player associations" do
    jim = create(:user, username: "jim")
    game = create(:game, :modern_art)
    table = GameSession::Create.!(game).subject
    player = Player::Create.!(jim, session: table).subject
    original = [ jim.id, player.id, player.game_session_id, player.created_at ]
    options = { profile: jim, issuer: issuer, subject: "canonical-subject", evidence: "owner-confirmed-auth-receipt" }

    identity = ReconcileAuthIdentity.call(**options, operation: "link")
    expect(ReconcileAuthIdentity.call(**options, operation: "link")).to eq(identity)
    callback(start)
    expect(response).to have_http_status(:redirect)
    expect(AuthLogin.last.auth_identity.user_id).to eq(jim.id)
    get game_session_path(table.uid), as: :json
    expect(response).to have_http_status(:ok)

    2.times { ReconcileAuthIdentity.call(**options.merge(evidence: "owner-revoked"), operation: "revoke") }
    expect(AuthLogin.where(auth_identity: identity)).to be_empty
    get game_session_path(table.uid), as: :json
    expect(response).to have_http_status(:unauthorized)
    callback(start)
    expect(response).to have_http_status(:unauthorized)

    ReconcileAuthIdentity.call(**options, operation: "link")
    callback(start)
    expect(response).to have_http_status(:redirect)
    expect(AuthIdentityDecision.where(auth_identity: identity).order(:id).pluck(:action)).to eq(%w[linked revoked linked])
    expect([ jim.reload.id, player.reload.id, player.game_session_id, player.created_at ]).to eq(original)
    expect(User.where(username: "jim").count).to eq(1)
    expect do
      ReconcileAuthIdentity.call(**options.merge(subject: "different-subject"), operation: "link")
    end.to raise_error(ReconcileAuthIdentity::Conflict)
  end

  context "with approved production owner reconciliation" do
    let(:issuer) { "https://auth.harvj.com" }
    let(:redirect_uri) { "https://gaming.harvj.com/auth/callback" }
    let(:subject) { "11111111-2222-4333-8444-555555555555" }
    let(:evidence) { "RG-P15-PROD-AUTH-OWNER-136-2" }
    let!(:owner) { create(:user, id: 1, username: "jim") }

    before do
      allow(ProductionOwnerBootstrap).to receive(:enabled?).and_return(true)
      allow(HistoricalUserAdministration).to receive_messages(owner_subject: subject, owner_evidence: evidence)
      Player.insert_all!(Array.new(83) { { user_id: owner.id } })
    end

    it "links only after signed owner verification without changing the historical profile or associations" do
      seats = owner.players.order(:id).pluck(:id)
      callback(start, sub: subject, nonce: "incorrect")
      expect(response).to have_http_status(:unauthorized)
      callback(start, sub: "different-subject")
      expect(response).to have_http_status(:unauthorized)
      expect(owner.reload.auth_identity).to be_nil

      expect { callback(start, sub: subject) }.not_to change(User, :count)
      expect(response).to have_http_status(:redirect)
      identity = owner.reload.auth_identity
      expect(identity).to have_attributes(issuer: issuer, subject: subject)
      expect(AuthIdentityDecision.where(auth_identity: identity).sole).to have_attributes(action: "linked", evidence_reference: evidence)
      expect(owner.players.order(:id).pluck(:id)).to eq(seats)
      expect(AuthLogin.last.auth_identity).to eq(identity)
    end

    it "preserves a revoked production link" do
      AuthIdentity.create!(user: owner, issuer: issuer, subject: subject, evidence_reference: evidence, revoked_at: 1.minute.ago)
      expect { callback(start, sub: subject) }.not_to change(AuthLogin, :count)
      expect(response).to have_http_status(:unauthorized)
      expect(owner.reload.auth_identity.revoked_at).to be_present
    end
  end

  context "with the protected staging owner approval" do
    let(:issuer) { "https://auth.harvj.com" }
    let(:redirect_uri) { "https://#{ModernArtStaging::GAME_HOST}/auth/callback" }
    let(:subject_id) { "11111111-2222-4333-8444-555555555555" }
    let(:evidence) { "RG-STAGING-AUTH-OWNER-118-2" }
    let(:owner) { create(:user, username: "jim") }

    before do
      allow(ModernArtStaging).to receive(:enabled?).and_return(true)
      allow(ModernArtStaging).to receive(:owner_subject).and_return(subject_id)
      allow(ModernArtStaging).to receive(:owner_evidence).and_return(evidence)
      stub_const("ModernArtStaging::OWNER_PROFILE_ID", owner.id)
      create(:game, key: ModernArtStaging::GAME_KEY)
      Player.insert_all!(Array.new(83) { { user_id: owner.id } })
    end

    it "creates the owner link only after a verified signed callback and preserves the historical associations" do
      historical_players = owner.players.order(:id).pluck(:id)
      callback(start, sub: subject_id, nonce: "incorrect")
      expect(response).to have_http_status(:unauthorized)
      expect(owner.reload.auth_identity).to be_nil

      callback(start, sub: subject_id)
      expect(response).to have_http_status(:redirect)
      expect(AuthLogin.last.auth_identity.user_id).to eq(owner.id)
      expect(owner.reload.auth_identity.evidence_reference).to eq(evidence)
      expect(AuthIdentityDecision.where(auth_identity: owner.auth_identity).pluck(:action)).to eq([ "linked" ])
      expect(owner.players.order(:id).pluck(:id)).to eq(historical_players)

      login = AuthLogin.last
      login.update!(expires_at: 1.second.ago)
      expect(AuthLogin.authorized(login.id)).to be_nil
    end

    it "denies a different, validly signed and locally linked subject" do
      other = AuthIdentity.create!(issuer: issuer, subject: "not-the-approved-owner",
        user: profile, evidence_reference: "fixture-link")
      login = AuthLogin.create!(auth_identity: other, assurance: CanonicalAuth::PASSWORD, expires_at: 5.minutes.from_now)
      expect(AuthLogin.authorized(login.id)).to be_nil
      callback(start, sub: other.subject)
      expect(response).to have_http_status(:unauthorized)
      expect(owner.reload.auth_identity).to be_nil
    end

    it "never reactivates a revoked owner link on callback" do
      AuthIdentity.create!(user: owner, issuer: issuer, subject: subject_id,
        evidence_reference: evidence, revoked_at: 1.minute.ago)
      expect { callback(start, sub: subject_id) }.not_to change(AuthLogin, :count)
      expect(response).to have_http_status(:unauthorized)
      expect(owner.reload.auth_identity.revoked_at).to be_present
    end
  end
end
