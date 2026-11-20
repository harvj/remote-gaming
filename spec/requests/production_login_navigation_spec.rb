require "rails_helper"

RSpec.describe "Production login navigation", type: :request do
  it "keeps both public hosts anonymous and selects the registered host before creating an OIDC attempt" do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(CanonicalAuth).to receive(:enabled?).and_return(false)
    Rails.application.reload_routes!
    GameDirectory::DIRECTORY_HOSTS.each do |host|
      host! host
      get "/"
      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML5(response.body).at_css(".directory-login")["href"]).to eq("/login")
      expect { get "/login" }.not_to change(AuthLoginAttempt, :count)
      expect(response).to have_http_status(:service_unavailable)
      expect(response.headers["Location"]).to be_nil
    end

    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    Rails.application.reload_routes!
    host! "radioactivita.com"
    expect { get "/login" }.not_to change(AuthLoginAttempt, :count)
    expect(response).to redirect_to("https://gaming.harvj.com/login?return_to=%2F")
    get "/auth/callback", params: { state: "fixture", code: "fixture" }
    expect(response).to have_http_status(:not_found)

    host! "gaming.harvj.com"
    get "/auth/callback", params: { state: "fixture", code: "fixture" }
    expect(response).to have_http_status(:unauthorized)
  ensure
    allow(Rails.env).to receive(:production?).and_call_original
    Rails.application.reload_routes!
  end
end
