require "rails_helper"

RSpec.describe "Canonical Auth", type: :request do
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwks) { { keys: [ JWT::JWK.new(key.public_key, "auth-key").export ] } }
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
    allow_any_instance_of(CanonicalAuth).to receive(:fetch_json).and_return({ "id_token" => token }, jwks)
    get "/auth/callback", params: { state: authorization.fetch("state"), code: "fixture-code" }
  end

  it "authenticates a linked historical profile with password assurance and logs out locally" do
    create(:game, key: "modern_art")
    AuthIdentity.create!(issuer: issuer, subject: "canonical-subject", user: profile, evidence_reference: "approval-123")
    expect(start.fetch("code_challenge_method")).to eq("S256")
    callback(start)
    expect(response).to have_http_status(:redirect)
    expect(AuthLogin.last.auth_identity.user_id).to eq(profile.id)
    expect(AuthLogin.last.assurance).to eq(CanonicalAuth::PASSWORD)
    get "/users/radio"
    expect(response).to have_http_status(:ok)
    delete "/logout"
    expect(response).to have_http_status(:see_other)
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
end
