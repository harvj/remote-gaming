require "rails_helper"

RSpec.describe "Public historical tabletop", type: :system do
  it "opens from the public list, inspects approved hands and rules, and stays read-only at desktop and mobile widths" do
    game = create(:game, :modern_art)
    table = game.sessions.create!(uid: "explorer-fixture", state: "completed", completed_at: Time.zone.parse("2026-11-15"))
    roster = %w[Alex Morgan Robin].map.with_index do |name, index|
      role = game.roles.create!(name: %w[tokyo berlin bilbao][index])
      table.all_players.create!(user: create(:user, name: name), game_id: game.id, role: role, turn_order: index + 1,
        score: [ 510, 630, 586 ][index], winner: index == 1, action_phase: "idle")
    end
    deck = table.decks.create!(key: "default")
    definitions = game.cards.order(:id).to_a
    roster.each_with_index do |seat, index|
      [ 16, 0, 9, 4, 23, 13 ].rotate(index).first(5).each do |definition|
        deck.cards.create!(session: table, card: definitions.fetch(definition), player: seat, dealt_at: 1.day.ago)
      end
    end
    stub_const("HistoricalExplorer::HOST", "127.0.0.1")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_HISTORICAL_EXPLORER").and_return("1")
    allow(ENV).to receive(:fetch).with("REMOTE_GAMING_PUBLIC_HISTORICAL_SESSIONS", "{}")
      .and_return({ table.uid => HistoricalExplorer::FIELDS }.to_json)

    browser = page.driver.browser
    if ENV["EXPLORER_SCREENSHOTS"]
      manifest = File.read("tmp/shell-live-art.json")
      browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
        sessionStorage.setItem("site-art.manifest", #{manifest.to_json});
        sessionStorage.setItem("site-art.last-attempt", Date.now());
      JS
    end
    [ 1440, 390 ].each do |width|
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 980,
        deviceScaleFactor: 1, mobile: width <= 700)
      visit "/"
      expect(page).to have_text("Morgan · Winner")
      expect(page).to have_no_button("Create New")
      screenshot("listing", width)
      click_link "November 15, 2026"
      expect(page).to have_text("Final cash")
      expect(page).to have_text("$630k")
      expect(page).to have_css("img[alt='berlin']")
      expect(page).to have_no_css("button[data-card-id]")
      expect(page).to have_no_button("Bid")
      select "Morgan", from: "Player"
      within(".hand") do
        expect(page).to have_text("$630k")
        button = find("button", text: /^Sort hand:/)
        3.times { button.click unless button.text == "Sort hand: Auction type" }
        expect(button.text).to eq("Sort hand: Auction type")
        check "Group by artist"
        expect(page).to have_css("[data-card-id]", count: 5)
      end
      geometry = page.evaluate_script("[innerWidth, document.documentElement.scrollWidth === document.documentElement.clientWidth]")
      expect(geometry).to eq([ width, true ])
      screenshot("tabletop", width)
      click_button "Game Rules"
      expect(page).to have_css("dialog[open]", text: "Modern Art rules")
      find('dialog button[aria-label="Close game rules"]').click
      expect(page).to have_no_css("dialog[open]")
    end
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def screenshot(surface, width)
    return unless ENV["EXPLORER_SCREENSHOTS"]

    expect(page).to have_css("body[data-site-art-background]")
    page.evaluate_async_script("document.fonts.ready.then(arguments[0])")
    viewport = width <= 700 ? "mobile" : "desktop"
    page.save_screenshot(File.join(ENV.fetch("EXPLORER_SCREENSHOTS"), "#{surface}-#{viewport}.png"))
  end
end
