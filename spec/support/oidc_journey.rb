module OidcJourney
  def stub_oidc_journey(provider, identity, code: "fixture", assurance: CanonicalAuth::PASSWORD, destination: "/up")
    attempt = { "state" => "fixture", "nonce" => "fixture-nonce", "verifier" => "fixture-verifier",
      "expires" => 10.minutes.from_now.to_i }
    allow(provider).to receive(:start).and_return(attempt)
    allow(provider).to receive(:authorization_url).with(attempt).and_return(destination)
    allow(provider).to receive(:authenticate).with(attempt, state: "fixture", code: code)
      .and_return([ identity, assurance, "fixture-access-token", 300 ])
    allow(provider).to receive(:active_access_token?).with("fixture-access-token").and_return(true)
    allow(provider).to receive(:revoke).with("fixture-access-token")
  end
end
