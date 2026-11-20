require "rails_helper"

RSpec.describe "Game directory", type: :request do
  GameDirectory::DIRECTORY_HOSTS.each do |host|
    it "lists games with honest availability at #{host}" do
      host! host
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Not yet available")
      page = Nokogiri::HTML5(response.body)
      expect(page.css("h1").map { |heading| heading.text.strip }).to eq([ "remote-gaming." ])
      expect(page.css("main .directory-cards > li").size).to eq(3)
      expect(page.at_css("#site-art-icon")["data-art-id"]).to eq("remote-gaming.favicon")
      expect(page.at_css("main").text).not_to include("What are we playing?")
      expect(response.body).to include('href="https://arkham.radioactivita.com/"')
      expect(page.at_css(".directory-wordmark")["href"]).to eq("/")
      expect(page.at_css(".directory-nav a").text).to eq("Log in")
      expect(page.at_css(".directory-nav a")["href"]).to eq("/login")
      expect(page.at_css("footer a").text).to eq("Jim Harvey")
      expect(page.at_css("footer a")["href"]).to eq("https://harvj.com")
      expect(page.at_css("footer").text).to include(Rails.configuration.x.directory_release_label)
      expect(response.body).not_to include('class="directory-apps"')
      expect(response.body).not_to include('href="https://pandemic.radioactivita.com/"')
    end
  end

  it "selects the distinct staging asset using staging deployment configuration" do
    allow(ModernArtStaging).to receive(:enabled?).and_return(true)
    host! "radioactivita.com"
    get "/"

    icon = Nokogiri::HTML5(response.body).at_css("#site-art-icon")
    expect(icon["data-art-id"]).to eq("remote-gaming.favicon_staging")
    expect(icon["href"]).to eq("/icon-staging.svg")
    expect(response.body).not_to include('href="/icon.png"')
  end

  { "modernart" => "Modern Art", "pandemic" => "Pandemic" }.each do |slug, title|
    it "shows the status page for #{title}" do
      host! "#{slug}.radioactivita.com"
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<h1>#{title}</h1>", "Not yet available")
      expect(Nokogiri::HTML5(response.body).at_css(".directory-wordmark")["href"]).to eq("/")
    end
  end

  %w[arkham unknown-game].each do |slug|
    it "does not serve #{slug} as a Remote Gaming game" do
      host! "#{slug}.radioactivita.com"
      get "/"

      expect(response).to have_http_status(:not_found)
    end
  end

  it "offers a safe retry while Auth is unconfigured and refuses local password submissions" do
    get "/login"
    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include("Try signing in again")
    post "/login", params: { user: { username: "fixture", password: "fixture" } }
    expect(response).to have_http_status(:not_found)
  end

  it "boots and can query the migrated database" do
    host! "radioactivita.com"
    get "/up"
    expect(response).to have_http_status(:ok)
    get "/ready"
    expect(response).to have_http_status(:ok)
  end

  it "reports failed database readiness without returning the error" do
    allow(Game.connection_pool).to receive(:with_connection).and_raise(ActiveRecord::ConnectionNotEstablished)
    get "/ready"

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to be_empty
  end
end
