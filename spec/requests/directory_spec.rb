require "rails_helper"

RSpec.describe "Game directory", type: :request do
  GameDirectory::DIRECTORY_HOSTS.each do |host|
    it "lists games with honest availability at #{host}" do
      host! host
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<h1>Remote Gaming</h1>", "What are we playing?", "Not yet available")
      expect(response.body).to include('href="https://arkham.radioactivita.com/"')
      expect(response.body).not_to include('href="https://pandemic.radioactivita.com/"')
    end
  end

  { "modernart" => "Modern Art", "pandemic" => "Pandemic" }.each do |slug, title|
    it "shows the status page for #{title}" do
      host! "#{slug}.radioactivita.com"
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<h1>#{title}</h1>", "Not yet available")
    end
  end

  %w[arkham unknown-game].each do |slug|
    it "does not serve #{slug} as a Remote Gaming game" do
      host! "#{slug}.radioactivita.com"
      get "/"

      expect(response).to have_http_status(:not_found)
    end
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
