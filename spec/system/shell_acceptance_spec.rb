require "rails_helper"

RSpec.describe "Signed Application Shell acceptance", type: :system do
  let(:provider) { instance_double(CanonicalAuth) }
  let(:issuer) { "https://auth.harvj.com" }
  let(:username) { "abcdefghijklmnopqrstuvwxyz123456" }

  def browser
    page.driver.browser
  end

  def viewport(width)
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900,
      deviceScaleFactor: 1, mobile: width <= 700)
    browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: width <= 700)
  end

  def sign_in
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_CLIENT_ID").and_return("gaming")
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    owner = create(:user, id: 1, username: "jim")
    identity = ReconcileAuthIdentity.call(profile: owner, issuer: issuer, subject: "owner",
      evidence: "fixture", operation: "link")
    allow(HistoricalUserAdministration).to receive_messages(available_on?: true, owner_subject: "owner", owner_evidence: "fixture")
    stub_oidc_journey(provider, identity, username: username)
    allow(provider).to receive(:shell_evidence) do
      { "eligible_destination_ids" => [ "continuum" ], "exp" => 45.seconds.from_now.to_i }
    end
    allow(ShellRegistry).to receive(:destinations).with([ "continuum" ])
      .and_return([ { name: "Library", url: "https://library.harvj.com/" } ])
    visit "/login"
    visit "/auth/callback?state=fixture&code=fixture"
  end

  it "uses the signed font bytes, wordmark line box, controls and mobile second row on applicable surfaces" do
    game = create(:game, :modern_art)
    sign_in
    [ 320, 390, 700, 701, 1440 ].each do |width|
      viewport(width)
      [ root_path, historical_users_path, game_path(game.key) ].each do |route|
        visit route
        expect(page).to have_css(".shell-header-row .shell-trigger--identity")
        expect_geometry(width)
        if route == game_path(game.key)
          expect(page).to have_css('nav[aria-label="Primary navigation"] [aria-current="page"]')
          rows = page.evaluate_script(<<~JS)
            [".shell-brand", ".shell-primary"].map(selector => document.querySelector(selector).getBoundingClientRect().top)
          JS
          expect(rows.last > rows.first).to eq(width <= 700)
        end
      end
    end
  end

  it "starts with a closed disclosure, preserves identity through traversal and clears authenticated controls after logout" do
    viewport(390)
    sign_in
    visit root_path
    trigger = find("summary")
    expect(accessible_node(username).fetch("properties")).to include(
      a_hash_including("name" => "expanded", "value" => a_hash_including("value" => false))
    )
    expect(accessible_node("Library")).to be_nil
    trigger.send_keys(:enter)
    expect(page).to have_link("Library")
    expect(accessible_node("Library").dig("role", "value")).to eq("link")
    find_link("Library").send_keys(:tab)
    expect(page).to have_css("a:focus", text: "Account Settings")
    browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
    expect(page).to have_css("a:focus", text: "Library")
    browser.action.send_keys(:escape).perform
    expect(page).to have_css("summary:focus", text: username)
    expect(page).to have_no_link("Library")
    visit historical_users_path
    page.go_back
    expect(page).to have_css("summary", text: username)
    expect(page).to have_no_link("Library")
    page.go_forward
    expect(page).to have_current_path(historical_users_path)
    trigger = find("summary", text: username)
    trigger.send_keys(:space)
    expect(page).to have_link("Library")
    click_button "Log Out"
    expect(page).to have_current_path("/up")
    visit root_path
    expect(page).to have_link("Log In", href: "/login")
    page.go_back
    expect(page).to have_no_css(".shell-trigger--identity")
    expect(page).to have_no_link("Library")
    page.go_back
    expect(page).to have_current_path(historical_users_path)
    expect(page).to have_no_css(".shell-trigger--identity")
    expect(page).to have_no_link("Library")
  end

  it "keeps the first-row trigger usable by touch and respects forced colors and reduced motion" do
    viewport(320)
    browser.execute_cdp("Network.enable")
    browser.execute_cdp("Network.setBlockedURLs", urls: [ "https://art.harvj.com/*" ])
    browser.execute_cdp("Emulation.setEmulatedMedia", features: [
      { name: "prefers-color-scheme", value: "dark" }, { name: "prefers-reduced-motion", value: "reduce" }
    ])
    sign_in
    visit root_path
    expect(page).to have_no_css("body[data-site-art-background]")
    expect(page).to have_css("summary", text: username)
    point = browser.execute_script(<<~JS)
      const r = document.querySelector("summary").getBoundingClientRect();
      return {x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)};
    JS
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [ point ])
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
    expect(page).to have_link("Account Settings")
    dimensions = browser.execute_script(<<~JS)
      const target = document.querySelector("summary").getBoundingClientRect();
      const panel = document.querySelector(".shell-panel").getBoundingClientRect();
      const link = document.querySelector(".shell-panel a");
      return [panel.top-target.bottom, panel.width, panel.right, target.right,
        link.getBoundingClientRect().height, getComputedStyle(link).transitionDuration];
    JS
    gap, width, right, target_right, height, duration = dimensions
    expect(gap).to eq(8)
    expect(width).to eq(264)
    expect(right).to eq(target_right)
    expect(height).to be >= 44
    expect(duration).to eq("0s")

    browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "forced-colors", value: "active" } ])
    expect(browser.execute_script("return getComputedStyle(document.querySelector('#site-art-background')).display")).to eq("none")
    expect(page).to have_link("Account Settings")
    expect(page).to have_button("Log Out")
  ensure
    browser.execute_cdp("Network.setBlockedURLs", urls: [])
    browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  it "keeps the oak account control readable and the staging header usable while scrolling" do
    allow(ModernArtStaging).to receive_messages(enabled?: true, owner_subject: "owner")
    create(:game, :modern_art)
    sign_in
    [ 320, 390, 700, 701, 1440 ].each do |width|
      viewport(width)
      visit root_path
      trigger = find("summary", text: username)
      expect_geometry(width)
      trigger.hover
      expect(trigger.style("color", "background-color")).to eq(
        "color" => "rgba(255, 243, 222, 1)", "background-color" => "rgba(75, 49, 32, 1)"
      )
      browser.execute_script("document.querySelector('main').style.minHeight = '150vh'; window.scrollTo(0, 400)")
      expect(page.evaluate_script("document.querySelector('header').getBoundingClientRect().top")).to eq(0)
      expect(page.evaluate_script("getComputedStyle(document.querySelector('header'), '::after').pointerEvents")).to eq("none")
      trigger.send_keys(:space)
      expect(page).to have_link("Account Settings")
      browser.action.send_keys(:escape).perform
      expect(page).to have_css("summary:focus", text: username)
    end
  end

  def accessible_node(name)
    browser.execute_cdp("Accessibility.getFullAXTree").fetch("nodes").find do |node|
      node.dig("name", "value") == name && !node.fetch("ignored")
    end
  end

  def expect_geometry(width)
    result = browser.execute_script(<<~JS)
      const brand = document.querySelector(".shell-brand a");
      const target = document.querySelector(".shell-trigger--identity");
      const box = brand.getBoundingClientRect();
      const control = target.getBoundingClientRect();
      const style = getComputedStyle(brand);
      return [box.x, box.y, box.y + box.height / 2, innerWidth - control.right,
        control.y + control.height / 2, control.height, style.fontFamily, style.fontSize,
        style.fontWeight, style.letterSpacing, document.documentElement.scrollWidth];
    JS
    x, top, brand_middle, right, control_middle, target, font, size, weight, tracking, scroll = result
    mobile = width <= 700
    expect(x).to be_within(0.03).of(mobile ? 28 : width * 0.065)
    expect(right).to be_within(0.03).of(x)
    expect(top).to be_within(0.03).of(mobile ? 27 : 35), "unexpected geometry at #{width} on #{page.current_path}: #{result.inspect}"
    expect(control_middle).to be_within(0.03).of(brand_middle)
    expect(target).to be >= 44
    expect(font).to start_with("DM,")
    expect(size).to eq(mobile ? "23px" : "24px")
    expect(weight).to eq("600")
    expect(tracking).to eq("-1.2px")
    expect(scroll).to eq(width)
  end
end
