require "rails_helper"

RSpec.describe "Modern Art practice access", type: :request do
  it "fails closed on the staging game host until opted in, for guests, and on the staging directory" do
    create(:game, :modern_art)
    allow(ModernArtStaging).to receive(:enabled?).and_return(true)
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_MODERN_ART_PRACTICE").and_return("0")
    host! ModernArtStaging::GAME_HOST
    post "/practice"
    expect(response).to have_http_status(:not_found)
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_MODERN_ART_PRACTICE").and_return("1")
    post "/practice"
    expect(response).to have_http_status(:not_found)
    host! ModernArtStaging::DIRECTORY_HOST
    post "/practice"
    expect(response).to have_http_status(:not_found)
    expect(ModernArtPracticeTable.count).to eq(0)
  end
end
