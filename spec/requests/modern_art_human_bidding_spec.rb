require "rails_helper"

RSpec.describe "Recorded human Modern Art", type: :request do
  it "isolates seat grants and records sealed bidding from three independent sessions" do
    game = create(:game, :modern_art)
    owner = create(:user)
    stub_const("ModernArtStaging::OWNER_PROFILE_ID", owner.id)
    issuer = "https://auth.harvj.com"
    identity = AuthIdentity.create!(user: owner, issuer: issuer, subject: "human-owner", evidence_reference: "fixture")
    provider = instance_double(CanonicalAuth)
    allow(ModernArtStaging).to receive_messages(enabled?: true, owner_subject: identity.subject)
    allow(CanonicalAuth).to receive_messages(enabled?: true, new: provider)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_MODERN_ART_PRACTICE").and_return("1")
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_CLIENT_ID").and_return("practice")
    allow(SecureRandom).to receive(:random_number).and_call_original
    allow(SecureRandom).to receive(:random_number).with(2**32).and_return(411)
    stub_oidc_journey(provider, identity)
    host! ModernArtStaging::GAME_HOST
    get "/login"
    get "/auth/callback", params: { state: "fixture", code: "fixture" }
    post game_sessions_path, params: { game_key: game.key }
    table = ModernArtPracticeTable.find_by!(owner: owner)
    expect(table).to be_human
    endpoint = game_session_path(table.uid)

    peers = %w[Alex Morgan].map do |name|
      post session_dummies_path(table.uid), params: { seat_name: name }
      expect(response).to have_http_status(:created)
      code = Nokogiri::HTML(response.body).at_css("#dummy-credential").text
      browser = ActionDispatch::Integration::Session.new(Rails.application)
      browser.host! ModernArtStaging::GAME_HOST
      browser.post(dummy_login_path, params: { dummy_credential: code })
      expect(browser.response).to have_http_status(:see_other)
      browser
    end
    patch endpoint, params: { command: "start" }, as: :json
    expect(response).to have_http_status(:ok)
    card = response.parsed_body.fetch("hand").find { |item| item.fetch("kind") == "sealed" }
    patch endpoint, params: { command: "play", value: card.fetch("id"), revision: 0 }, as: :json
    expect(response.parsed_body.fetch("phase")).to eq("sealed")
    expect(table.reload.commands.size).to eq(1)

    peers.first.get endpoint, as: :json
    expect(peers.first.response.parsed_body.fetch("players").select { |player| player.key?("cash") }.size).to eq(1)
    peers.first.patch endpoint, params: { command: "bid", value: 14, revision: 1, seat: 0 }, as: :json
    expect(peers.first.response).to have_http_status(:ok)
    expect(table.reload.commands.last).to eq([ peers.first.response.parsed_body.fetch("viewerSeat"), "bid", 14, 1, "sealed" ])
    get endpoint, as: :json
    expect(response.parsed_body.fetch("bidHistory")).to be_empty
    peers.last.patch endpoint, params: { command: "bid", value: 16, revision: 1 }, as: :json
    expect(peers.last.response).to have_http_status(:conflict)
    peers.last.patch endpoint, params: { command: "bid", value: 16, revision: 2 }, as: :json
    expect(peers.last.response).to have_http_status(:ok)
    patch endpoint, params: { command: "bid", value: 17, revision: 3 }, as: :json
    expect(response.parsed_body.fetch("bidHistory").pluck("amount")).to eq([ 14, 16, 17 ])
    expect(response.parsed_body.fetch("settlements").last).to include("auction" => 1, "winner" => 0, "amount" => 17)
    expect(table.reload.replay).to eq(table.position)
    get session_replay_path(table.uid), params: { frame: 2 }, as: :json
    expect(response.parsed_body.values_at("legal", "bidHistory")).to eq([ {}, [] ])

    receivers = [ self, *peers ]
    500.times do
      table.reload
      rules = Games::ModernArt::PracticeRules.new(table.position)
      phase = table.position.fetch("phase")
      break if phase == "complete"

      commanded = if phase == "scoring"
        [ 1, "advance", nil ]
      else
        receivers.each_index.filter_map do |seat|
          choice = Games::ModernArt::PracticeOpponent.choose(rules, seat)
          [ seat, *choice ] if choice
        end.first
      end
      seat, action, amount = commanded
      receivers.fetch(seat).patch endpoint, params: { command: action, value: amount, revision: table.commands.size }, as: :json
      expect(receivers.fetch(seat).response).to have_http_status(:ok)
    end
    expect(table.reload.position.fetch("phase")).to eq("complete")
    expect(table.position.fetch("seasons").length).to eq(4)
    expect(table.replay).to eq(table.position)
    expect(table.commands.filter_map { |_, action, _, _, phase| phase if %w[bid pass buy price].include?(action) })
      .to include("open", "once_around", "sealed", "fixed_price", "fixed_offer", "pair")

    session = GameSession.find_by!(uid: table.uid)
    delete session_dummy_path(table.uid, session.players.joins(:dummy_access).first.id)
    peers.first.patch endpoint, params: { command: "pass", revision: 4 }, as: :json
    expect(peers.first.response).to have_http_status(:not_found)
  end
end
