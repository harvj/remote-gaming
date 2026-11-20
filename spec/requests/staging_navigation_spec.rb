require "rails_helper"

RSpec.describe "Staging navigation", type: :request do
  it "keeps the staging directory protected and renders local navigation on the canonical host" do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ModernArtStaging).to receive_messages(enabled?: true, owner_subject: "fixture-owner")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return("https://auth.harvj.com")
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    Rails.application.reload_routes!
    game_host = ModernArtStaging::GAME_HOST
    create(:game, :modern_art)

    host! ModernArtStaging::DIRECTORY_HOST
    get "/"
    expect(response).to have_http_status(:ok)
    get "/login"
    expect(response).to redirect_to("https://#{game_host}/login?return_to=%2Fstaging%2Fdirectory")

    host! game_host
    get "/staging/directory"
    expect(response).to redirect_to("/login")
    get "/signed-out"
    expect(response).to have_http_status(:ok)
    signed_out = Nokogiri::HTML5(response.body)
    navbar = JSON.parse(signed_out.at_css("#navbar-data").text)
    expect(navbar).to include("loginPath" => "/login", "currentUser" => nil)
    expect(signed_out.at_css("footer a")["href"]).to eq("https://harvj.com")
    expect(signed_out.css('input[type="password"]')).to be_empty

    owner = create(:user, id: ModernArtStaging::OWNER_PROFILE_ID, username: "jim")
    identity = AuthIdentity.create!(user: owner, issuer: "https://auth.harvj.com", subject: "fixture-owner",
      evidence_reference: "staging-fixture")
    provider = instance_double(CanonicalAuth)
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    stub_oidc_journey(provider, identity, destination: "https://auth.harvj.com/authorize")
    get "/login"
    expect(response).to redirect_to("https://auth.harvj.com/authorize")
    get "/auth/callback", params: { state: "fixture", code: "fixture" }
    expect(response).to redirect_to("/staging/directory")
    get "/staging/directory"
    directory = Nokogiri::HTML5(response.body)
    expect(directory.at_css(".directory-wordmark")["href"]).to eq("/")
    expect(directory.at_css(".directory-apps")).to be_present
    expect(directory.at_css(".directory-login")).to be_nil
    expect(directory.at_css("footer a")["href"]).to eq("https://harvj.com")

    get "/"
    expect(response).to redirect_to("/modern_art")
    follow_redirect!
    game = Nokogiri::HTML5(response.body)
    expect(JSON.parse(game.at_css("#navbar-data").text).dig("currentUser", "name")).to eq("jim")
    expect(game.at_css("footer a").text).to eq("Jim Harvey")
  ensure
    allow(Rails.env).to receive(:production?).and_call_original
    Rails.application.reload_routes!
  end
end
