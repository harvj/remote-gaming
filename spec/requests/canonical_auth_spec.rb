require "rails_helper"

RSpec.describe "Canonical Auth", type: :request do
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwks) { { "keys" => [ JWT::JWK.new(key.public_key, "auth-key").export ] } }
  let(:profile) { create(:user, username: "radio") }
  let(:issuer) { "https://auth.example.test" }

  around do |example|
    config = {
      "REMOTE_GAMING_OIDC_ISSUER" => "https://auth.example.test", "REMOTE_GAMING_OIDC_CLIENT_ID" => "gaming",
      "REMOTE_GAMING_OIDC_CLIENT_SECRET" => "fixture", "REMOTE_GAMING_OIDC_REDIRECT_URI" => "https://www.example.com/auth/callback"
    }
    previous = ENV.to_h.slice(*config.keys)
    ENV.update(config)
    example.run
  ensure
    config.keys.each { |key| ENV.delete(key) }
    ENV.update(previous)
  end

  def start
    post "/auth/start"
    expect(response).to have_http_status(:redirect)
    URI.decode_www_form(URI(response.location).query).to_h
  end

  def callback(authorization, claims = {})
    attributes = { iss: issuer, aud: "gaming", sub: "canonical-subject", nonce: authorization.fetch("nonce"),
      iat: Time.current.to_i, exp: 5.minutes.from_now.to_i, acr: CanonicalAuth::PASSWORD }.merge(claims)
    token = JWT.encode(attributes, key, "RS256", kid: "auth-key")
    allow_any_instance_of(CanonicalAuth).to receive(:fetch_json) do |_provider, uri, request|
      expect(uri.host).to eq("auth.example.test")
      if request.is_a?(Net::HTTP::Post)
        expect(uri.path).to eq("/token")
        expect(request["Authorization"]).to eq("Basic #{Base64.strict_encode64('gaming:fixture')}")
        form = URI.decode_www_form(request.body).to_h
        challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(form.fetch("code_verifier")), padding: false)
        expect(challenge).to eq(authorization.fetch("code_challenge"))
        expect(form.fetch("redirect_uri")).to eq(authorization.fetch("redirect_uri"))
        { "id_token" => token }
      else
        expect(uri.path).to eq("/jwks")
        jwks
      end
    end
    get "/auth/callback", params: { state: authorization.fetch("state"), code: "fixture-code" }
  end

  it "authenticates a linked historical profile with password assurance and logs out locally" do
    host! "radioactivita.com"
    create(:game, key: "modern_art")
    AuthIdentity.create!(issuer: issuer, subject: "canonical-subject", user: profile, evidence_reference: "approval-123")
    expect(start.fetch("code_challenge_method")).to eq("S256")
    callback(start)
    expect(response).to have_http_status(:redirect)
    expect(AuthLogin.last.auth_identity.user_id).to eq(profile.id)
    expect(AuthLogin.last.assurance).to eq(CanonicalAuth::PASSWORD)
    get "/users/radio"
    expect(response).to have_http_status(:ok)
    get "/"
    expect(response.body).to include('class="directory-apps"', 'href="https://intelligence.harvj.com/"')
    expect(response.body).not_to include('aria-label="harvj.com home"')
    expect(response.headers["Cache-Control"]).to eq("no-store")
    delete "/logout"
    expect(response).to have_http_status(:see_other)
    get "/"
    expect(response.body).to include('aria-label="harvj.com home"')
    expect(response.body).not_to include('class="directory-apps"')
    get "/modern_art"
    expect(response).to have_http_status(:redirect)
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
  it "rejects an incomplete token response without opening a local login" do
    authorization = start
    allow_any_instance_of(CanonicalAuth).to receive(:fetch_json).and_return({ "id_token" => [] })

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
end
