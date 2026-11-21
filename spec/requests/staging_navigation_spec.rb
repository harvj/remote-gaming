require "rails_helper"

RSpec.describe "Staging navigation", type: :request do
  it "keeps the three staging hosts canonical and the authenticated game on its registered callback host" do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ModernArtStaging).to receive_messages(enabled?: true, owner_subject: "fixture-owner")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return("https://auth.harvj.com")
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_CLIENT_ID").and_return("staging-fixture-client")
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    Rails.application.reload_routes!
    game_host = ModernArtStaging::GAME_HOST
    create(:game, :modern_art)

    host! ModernArtStaging::DIRECTORY_HOST
    get "/"
    expect(response).to redirect_to("/directory")
    get "/directory"
    expect(response).to have_http_status(:ok)
    directory = Nokogiri::HTML5(response.body)
    expect(directory.at_css(".directory-wordmark")["href"]).to eq("https://#{ModernArtStaging::DIRECTORY_HOST}/")
    expect(directory.at_css('a[href="https://modern-art.staging.radioactivita.com/"]')).to be_present
    get "/auth/callback", params: { state: "fixture", code: "fixture" }
    expect(response).to have_http_status(:not_found)
    get "/login"
    expect(response).to redirect_to("https://#{game_host}/login?return_to=%2F")

    host! game_host
    get "/staging/directory"
    expect(response).to redirect_to("https://#{ModernArtStaging::DIRECTORY_HOST}/directory")
    get "/staging/pandemic"
    expect(response).to redirect_to("https://#{ModernArtStaging::PANDEMIC_HOST}/")
    get "/modern_art"
    expect(response).to redirect_to("/")
    get "/directory"
    expect(response).to have_http_status(:not_found)
    get "/"
    expect(response.body).to include("<h1>Modern Art</h1>")
    expect(response.body).not_to include("directory-cards", "games-show-data")
    get "/", as: :json
    expect(response).to have_http_status(:unauthorized)
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
    stub_oidc_journey(provider, identity, destination: "https://auth.harvj.com/authorize", username: "auth_jim")
    get "/login"
    expect(response).to redirect_to("https://auth.harvj.com/authorize")
    get "/auth/callback", params: { state: "fixture", code: "fixture" }
    expect(response).to redirect_to("/")
    get "/"
    expect(response).to have_http_status(:ok)
    game = Nokogiri::HTML5(response.body)
    navbar = JSON.parse(game.at_css("#navbar-data").text)
    expect(navbar.fetch("directoryHome")).to eq("https://#{ModernArtStaging::DIRECTORY_HOST}/")
    expect(navbar.fetch("currentGame")).to include("uri" => "/", "current" => true)
    expect(navbar.fetch("currentUser")).to include("name" => "auth_jim", "logoutPath" => "/logout",
      "accountPath" => "https://auth.harvj.com/account?client_id=staging-fixture-client")
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(game.at_css("footer a").text).to eq("Jim Harvey")
    delete "/logout"
    expect(response).to redirect_to("/")
    expect(AuthLogin.count).to eq(0)
    host! ModernArtStaging::PANDEMIC_HOST
    get "/"
    expect(response.body).to include("<h1>Pandemic</h1>")
    expect(response.body).not_to include("directory-cards", "games-show-data")
  ensure
    allow(Rails.env).to receive(:production?).and_call_original
    Rails.application.reload_routes!
  end
end
