require "rails_helper"

RSpec.describe "Production login navigation", type: :request do
  it "keeps both public hosts anonymous and selects the registered host before creating an OIDC attempt" do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(CanonicalAuth).to receive(:enabled?).and_return(false)
    Rails.application.reload_routes!
    (GameDirectory::DIRECTORY_HOSTS + %w[modernart.radioactivita.com pandemic.radioactivita.com]).each do |host|
      host! host
      expect { get "/" }.not_to change(AuthLoginAttempt, :count)
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML5(response.body)
      expect(page.at_css("header .directory-wordmark").text.strip).to eq("remote-gaming.")
      expect(page.at_css("header .directory-wordmark")["href"]).to eq(host == "gaming.harvj.com" ? "https://gaming.harvj.com/" : "https://radioactivita.com/")
      login = page.at_css('header nav[aria-label="Account navigation"] .directory-login')
      expect(login.text).to eq("Log In")
      expect(login["href"]).to eq("/login")
      expect(page.at_css('header nav[aria-label="Applications"], header .directory-apps')).to be_nil
      expect { get "/login", headers: { "Accept" => "*/*" } }.not_to change(AuthLoginAttempt, :count)
      expect(response).to have_http_status(:service_unavailable)
      expect(response.headers["Location"]).to be_nil
    end

    host! "arkham.radioactivita.com"
    get "/login"
    expect(response).to have_http_status(:not_found)

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
