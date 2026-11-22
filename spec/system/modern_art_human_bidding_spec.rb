require "rails_helper"

RSpec.describe "Human Modern Art auction presentation", type: :system do
  it "renders the legal human controls for every auction on the shared tabletop" do
    game = create(:game, :modern_art)
    owner = create(:user, id: 1)
    issuer = "https://auth.harvj.com"
    identity = AuthIdentity.create!(user: owner, issuer: issuer, subject: "human-owner", evidence_reference: "fixture")
    provider = instance_double(CanonicalAuth)
    allow(ModernArtStaging).to receive_messages(enabled?: true, owner_subject: identity.subject)
    stub_const("ModernArtStaging::GAME_HOST", "127.0.0.1")
    allow(CanonicalAuth).to receive_messages(enabled?: true, new: provider)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_MODERN_ART_PRACTICE").and_return("1")
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_CLIENT_ID").and_return("practice")
    stub_oidc_journey(provider, identity)

    browser = page.driver.browser
    if ENV["PRACTICE_SCREENSHOTS"]
      manifest = File.read("tmp/shell-live-art.json")
      browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
        try {
          sessionStorage.setItem("site-art.manifest", #{manifest.to_json});
          sessionStorage.setItem("site-art.last-attempt", Date.now());
        } catch {}
      JS
    end
    visit "/login"
    visit "/auth/callback?state=fixture&code=fixture"

    players = [ owner, create(:user, name: "Alex"), create(:user, name: "Morgan") ]
    options = {
      "open" => "Bid", "once_around" => "Bid", "sealed" => "Seal bid",
      "fixed" => "Set price", "double" => "Decline to pair"
    }
    options.each do |kind, button|
      session = GameSession::Create.!(game, experimental: true, experiment_owner: owner).subject
      roster = players.map { |player| Player::Create.!(player, session: session).subject }
      table = ModernArtPracticeTable.open!(owner, game, human_session: session)
      seed = (1..100).find do |candidate|
        initial = ModernArtPracticeTable.rules_for(table.setup.merge("seed" => candidate))
        hand = initial.projection(0).fetch(:hand)
        hand.any? { |card| card.fetch("kind") == kind }
      end
      table.setup["seed"] = seed
      table.save!
      table.begin_human!(roster)
      session.update!(state: "season_one", started_at: Time.current)
      card = table.human_view(owner).fetch(:hand).find { |item| item.fetch("kind") == kind }
      table.act!(0, "play", card.fetch("id"))
      if kind == "once_around"
        table.act!(1, "pass", nil, seat: 1)
        table.act!(2, "pass", nil, seat: 2)
      end

      visit game_session_path(session.uid)
      expect(page).to have_button(button)
      expect(page).to have_text("Recorded bidding and outcomes")
      [ 1440, 390 ].each do |width|
        browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 940,
          deviceScaleFactor: 1, mobile: width <= 700)
        expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(width)
        next unless ENV["PRACTICE_SCREENSHOTS"]

        expect(page).to have_css("body[data-site-art-background]")
        page.evaluate_async_script("document.fonts.ready.then(arguments[0])")
        size = width == 390 ? "mobile" : "desktop"
        page.save_screenshot(File.join(ENV.fetch("PRACTICE_SCREENSHOTS"), "human-#{kind.tr('_', '-')}-#{size}.png"))
      end
      next unless kind == "sealed"

      another = open_new_window
      within_window(another) do
        visit game_session_path(session.uid)
        expect(page).to have_button("Seal bid")
      end
      fill_in "Amount in $k", with: 12
      click_button "Seal bid"
      expect(page).to have_no_button("Seal bid")
      within_window(another) { expect(page).to have_no_button("Seal bid", wait: 5) }
      table.reload
      expect(table.commands.length).to eq(2)
      table.act!(2, "bid", 13, seat: 1)
      table.act!(3, "bid", 10, seat: 2)
      session.broadcast_live!
      within_window(another) do
        expect(page).to have_text("Alex acquired one painting for $13k.", wait: 5)
        visit session_replay_path(session.uid, frame: 2)
        expect(page).to have_text("Action 2 of 4")
        expect(page).to have_no_button("Seal bid")
        find("summary", text: "Recorded bidding and outcomes").click
        expect(page).to have_text("No bidding is visible yet.")
      end
    end
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
