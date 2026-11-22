require "rails_helper"

RSpec.describe "Modern Art private practice", type: :system do
  it "opens a table, keeps the opponent state private, and synchronizes a second browser window" do
    create(:game, :modern_art)
    owner = create(:user, id: 1, username: "jim")
    issuer = "https://auth.harvj.com"
    allow(ModernArtStaging).to receive_messages(enabled?: true, owner_subject: "practice-owner")
    stub_const("ModernArtStaging::GAME_HOST", "127.0.0.1")
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_MODERN_ART_PRACTICE").and_return("1")
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_CLIENT_ID").and_return("practice")
    identity = AuthIdentity.create!(user: owner, issuer: issuer, subject: "practice-owner", evidence_reference: "fixture")
    provider = instance_double(CanonicalAuth)
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    stub_oidc_journey(provider, identity)
    allow(SecureRandom).to receive(:random_number).and_call_original
    allow(SecureRandom).to receive(:random_number).with(2**32).and_return(411)

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
    visit "/practice"
    click_button "Start a practice game"
    expect(page).to have_css("h2", text: "Choose a painting")
    expect(page).to have_text("Maya Chen")
    expect(page).to have_text("Daniel Reyes")
    expect(page).to have_css("button[data-card-id]", count: 10)
    metadata = JSON.parse(find("#practice-table-data", visible: false).native.attribute("textContent"))
    expect(metadata.fetch("board").fetch("players").drop(1).any? { |player| player.key?("cash") }).to be(false)
    path = current_path
    verify_rules_drawer(browser)
    screenshot(browser, 1440, "hand-desktop")
    screenshot(browser, 390, "hand-mobile")

    hand = metadata.dig("board", "hand")
    expect(rendered_hand_ids).to eq(hand.pluck("id").map(&:to_s))
    check "Group by artist"
    expect(rendered_hand_ids).to eq(hand.group_by { |card| card.fetch("name") }.values.flatten.pluck("id").map(&:to_s))
    uncheck "Group by artist"
    click_button "Sort hand: Recorded order"
    expect(rendered_hand_ids).to eq(sorted_hand_ids(hand, "name"))
    click_button "Sort hand: Artist"
    expect(rendered_hand_ids).to eq(sorted_hand_ids(hand, "value"))
    click_button "Sort hand: Auction type"
    expect(rendered_hand_ids).to eq(hand.pluck("id").map(&:to_s))
    click_button "Sort hand: Recorded order"
    check "Group by artist"
    expect(page).to have_checked_field("Group by artist")
    expect(page).to have_button("Sort hand: Artist")
    screenshot(browser, 1440, "hand-sort-desktop", focus: ".hand-options")
    screenshot(browser, 390, "hand-sort-mobile", focus: ".hand-options")

    another = open_new_window
    within_window(another) do
      browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
        window.practiceSockets = [];
        window.WebSocket = class extends WebSocket {
          constructor(...args) {
            super(...args);
            window.practiceSockets.push(this);
          }
        };
      JS
      visit path
      expect(page).to have_css("h2", text: "Choose a painting")
      click_button "Sort hand: Recorded order"
      click_button "Sort hand: Artist"
    end
    find("button[data-card-id='#{hand.first.fetch('id')}']").click
    expect(page).to have_text("Recent actions")
    expect(page).to have_css(".activity [data-action-number='1']", text: "#1")
    screenshot(browser, 390, "auction-mobile")
    screenshot(browser, 1440, "auction-desktop")

    within_window(another) do
      expect(page).to have_text("Recent actions", wait: 5)
      stale_status = page.evaluate_async_script(<<~JS, metadata)
        const initial = arguments[0], done = arguments[1];
        fetch(initial.endpoint, {
          method: "PATCH",
          headers: { "Accept": "application/json", "Content-Type": "application/json", "X-CSRF-Token": initial.token },
          body: JSON.stringify({ command: "play", value: initial.board.hand[0].id, revision: 0 })
        }).then(response => done(response.status));
      JS
      expect(stale_status).to eq(409)
      refresh
      expect(page).to have_button("Sort hand: Auction type")
      expect(page).to have_css(".activity [data-action-number='1']", text: "#1")
    end

    within_window(another) do
      browser.execute_cdp("Network.emulateNetworkConditions", offline: true, latency: 0,
        downloadThroughput: -1, uploadThroughput: -1)
      page.execute_script("window.practiceSockets.at(-1).close()")
    end
    fill_in "Amount in $k", with: 0
    click_button "Seal bid"
    expect(page).to have_text("Daniel Reyes acquired one painting for $19k.")
    within_window(another) do
      browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: 0,
        downloadThroughput: -1, uploadThroughput: -1)
      Selenium::WebDriver::Wait.new(timeout: 15).until do
        page.evaluate_script("window.practiceSockets.length > 1 && window.practiceSockets.at(-1).readyState === WebSocket.OPEN")
      end
      expect(page).to have_text("Daniel Reyes acquired one painting for $19k.")
      expect(page).to have_button("Sort hand: Auction type")
    end

    in_table = ModernArtPracticeTable.find_by!(uid: metadata.fetch("uid"))
    expect(in_table.commands.size).to be > 0
    expect(in_table.replay).to eq(in_table.position)
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 940,
      deviceScaleFactor: 1, mobile: false)
    captured_score = false
    checked_new_cards = false
    225.times do
      in_table.reload
      rules = Games::ModernArt::PracticeRules.new(in_table.position)
      phase = rules.state.fetch("phase")
      break if phase == "complete"

      command, value = phase == "scoring" ? [ "advance", nil ] : Games::ModernArt::PracticeOpponent.choose(rules, 0)
      if phase == "scoring" && !captured_score
        screenshot(browser, 390, "settlement-mobile")
        captured_score = true
      end
      case command
      when "play" then find("button[data-card-id='#{value}']").click
      when "price", "bid"
        fill_in "Amount in $k", with: value
        click_button({ "fixed_price" => "Set price", "sealed" => "Seal bid" }.fetch(phase, "Bid"))
      when "pass" then click_button(phase == "pair" ? "Decline to pair" : "Pass")
      when "buy" then click_button("Buy lot")
      when "advance" then find(".auction button.action", text: /Continue|Reveal/).click
      end
      revision = in_table.commands.length
      Selenium::WebDriver::Wait.new(timeout: 5).until { in_table.reload.commands.length > revision }
      expect(page).to have_no_css(".auction button:disabled")
      if command == "advance" && !checked_new_cards
        next_hand = in_table.owner_view.fetch(:hand)
        expect(next_hand.pluck("id") - hand.pluck("id")).not_to be_empty
        expect(page).to have_button("Sort hand: Artist")
        expect(page).to have_checked_field("Group by artist")
        expect(rendered_hand_ids).to eq(sorted_hand_ids(next_hand, "name"))
        checked_new_cards = true
      end
    end
    expect(checked_new_cards).to be(true)
    expect(page).to have_css("h2", text: "Final results")
    expect(in_table.reload.replay).to eq(in_table.position)
    screenshot(browser, 1440, "results-desktop")
    screenshot(browser, 390, "results-mobile")
    visit "#{path}?frame=1"
    expect(page).to have_button("Sort hand: Artist")
    expect(page).to have_checked_field("Group by artist")
    expect(page).to have_css(".activity [data-action-number='1']", text: "#1")
    expect(page).to have_no_css("button[data-card-id]")
    click_link "Next action"
    expect(page).to have_css(".activity [data-action-number='1']", text: "#1")
    expect(page).to have_css(".activity [data-action-number='2']", text: "#2")
    visit path
    find("summary", text: "Remove this disposable table").click
    click_button "Delete practice table"
    expect(page).to have_button("Start a practice game")
    expect(ModernArtPracticeTable.exists?(in_table.id)).to be(false)
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def sorted_hand_ids(hand, field)
    hand.each_with_index.sort_by { |card, index| [ card.fetch(field), index ] }
      .map { |card, _| card.fetch("id").to_s }
  end

  def rendered_hand_ids
    all(".hand [data-card-id]").map { |card| card["data-card-id"] }
  end

  def verify_rules_drawer(browser)
    browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    [ 320, 390, 700, 701, 1440 ].each do |width|
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 740,
        deviceScaleFactor: 1, mobile: width <= 700)
      trigger = find_button("Game Rules")
      trigger.send_keys(:enter)
      dialog = find("dialog[open]")
      expect(dialog).to have_css("h2", text: "Game completion", visible: :all)
      measurements = page.evaluate_script(<<~JS)
        (() => {
          const box = document.querySelector("dialog").getBoundingClientRect();
          const content = document.querySelector(".modern-art-rules-content");
          return [Math.round(box.right), Math.round(box.height), Math.round(box.width),
            getComputedStyle(document.querySelector("dialog")).animationName,
            content.scrollHeight > content.clientHeight];
        })()
      JS
      expect(measurements).to eq([ width, 740, width <= 700 ? (width * 0.9).round : 448, "none", true ])
      expect(dialog).to have_css("button:focus", text: "×")
      if [ 390, 1440 ].include?(width) && ENV["PRACTICE_SCREENSHOTS"]
        viewport = width == 390 ? "mobile" : "desktop"
        page.evaluate_async_script("document.fonts.ready.then(arguments[0])")
        page.save_screenshot(File.join(ENV.fetch("PRACTICE_SCREENSHOTS"), "rules-drawer-#{viewport}.png"))
      end
      4.times { browser.action.send_keys(:tab).perform }
      expect(page.evaluate_script("document.querySelector('dialog').contains(document.activeElement)")).to be(true)
      browser.action.send_keys(:escape).perform
      expect(page).to have_no_css("dialog[open]")
      expect(page).to have_css("button[data-modern-art-rules-trigger]:focus")
      if width == 390
        trigger.click
        expect(page).to have_css("dialog[open]")
        browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [ { x: 8, y: 120 } ])
        browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
        expect(page).to have_no_css("dialog[open]")
        expect(page).to have_css("button[data-modern-art-rules-trigger]:focus")
      end
    end
    browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 940,
      deviceScaleFactor: 1, mobile: false)
  end

  def screenshot(browser, width, name, focus: nil)
    return unless ENV["PRACTICE_SCREENSHOTS"]

    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 940,
      deviceScaleFactor: 1, mobile: width <= 700)
    expect(page).to have_css("body[data-site-art-background]")
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(width)
    page.evaluate_async_script("document.fonts.ready.then(arguments[0])")
    if focus
      find(focus).execute_script(<<~JS)
        const inset = document.querySelector("body > header").getBoundingClientRect().height + 60;
        window.scrollBy({ top: this.getBoundingClientRect().top - inset, behavior: "instant" });
      JS
      browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseMoved", x: 3, y: 3)
    end
    page.save_screenshot(File.join(ENV.fetch("PRACTICE_SCREENSHOTS"), "#{name}.png"))
  end
end
