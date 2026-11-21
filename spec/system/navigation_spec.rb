require "rails_helper"

RSpec.describe "Remote Gaming navigation", type: :system do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  it "serves the same landing links on desktop and mobile and keeps the game wordmark local" do
    widths = [ 1280, 390 ]
    widths.each do |width|
      viewport(width)
      visit root_path
      expect(page).to have_link("remote-gaming.", href: "/")
      expect(page).to have_link("Log In", href: "/login")
      expect(page).to have_link("Jim Harvey", href: "https://harvj.com")
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(width)
    end

    user = create(:user)
    game = create(:game, :modern_art)
    login_as(user, scope: :user)
    table = GameSession::Create.!(game).subject
    widths.each do |width|
      viewport(width)
      visit game_session_path(table.uid)
      within("header.navbar") do
        expect(page).to have_link("remote-gaming.", href: "/")
        expect(page).to have_text("Logged in as")
        expect(page).to have_no_link("Log In")
        click_link "remote-gaming."
      end
      expect(page).to have_current_path(root_path)
      expect(page).to have_css(".directory-apps")
      expect(page).to have_link("Jim Harvey", href: "https://harvj.com")
    end
  end

  it "keeps verified account controls usable with a long Auth username on mobile" do
    issuer = "https://auth.fixture.test"
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_CLIENT_ID").and_return("gaming")
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    provider = instance_double(CanonicalAuth)
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    identity = AuthIdentity.create!(user: create(:user), issuer: issuer, subject: "owner", evidence_reference: "fixture")
    username = "abcdefghijklmnopqrstuvwxyz123456"
    stub_oidc_journey(provider, identity, username: username)

    viewport(390)
    visit "/login"
    visit "/auth/callback?state=fixture&code=fixture"
    visit root_path
    find(".directory-apps summary", text: username).click
    expect(page).to have_link("Account Settings", href: "#{issuer}/account?client_id=gaming")
    expect(page).to have_no_css('nav[aria-label="Applications"]')
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(390)

    game = create(:game, :modern_art)
    GameSession::Create.!(game)
    visit game_path(game.key)
    expect(page).to have_css(".session-link")
    click_button username
    expect(page).to have_link("Remote Gaming settings")
    expect(page).to have_link("Account Settings", href: "#{issuer}/account?client_id=gaming")
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(390)
    find_link("Account Settings").send_keys(:escape)
    expect(page).to have_no_link("Account Settings")
    expect(page).to have_css(".shell-account-button:focus", text: username)
  end

  it "renders verified Applications on directory, administration and Modern Art and removes expired links" do
    issuer = "https://auth.harvj.com"
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_CLIENT_ID").and_return("gaming")
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    provider = instance_double(CanonicalAuth)
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    owner = create(:user, id: 1, username: "jim")
    allow(HistoricalUserAdministration).to receive_messages(available_on?: true, owner_subject: "owner", owner_evidence: "fixture")
    identity = ReconcileAuthIdentity.call(profile: owner, issuer: issuer, subject: "owner",
      evidence: "fixture", operation: "link")
    username = "auth_jim"
    stub_oidc_journey(provider, identity, username: username)
    expires_at = -> { 45.seconds.from_now.to_i }
    allow(provider).to receive(:shell_evidence) do
      { "eligible_destination_ids" => [ "continuum" ], "exp" => expires_at.call }
    end
    allow(ShellRegistry).to receive(:destinations).with([ "continuum" ])
      .and_return([ { name: "Library", url: "https://library.harvj.com/" } ])
    game = create(:game, :modern_art)

    visit "/login"
    visit "/auth/callback?state=fixture&code=fixture"
    [ 1280, 390 ].each do |width|
      viewport(width)
      [ root_path, historical_users_path, game_path(game.key) ].each do |path|
        visit path
        if path == game_path(game.key)
          click_button username
        else
          find(".directory-apps summary", text: username).click
        end
        within('[aria-label="Applications"]') do
          expect(page).to have_link("Library", href: "https://library.harvj.com/")
        end
        expect(page).to have_link("Account Settings", href: "#{issuer}/account?client_id=gaming")
      end
    end

    expires_at = -> { 2.seconds.from_now.to_i }
    click_button username
    click_button username
    expect(page).to have_css('[aria-label="Applications"]')
    expect(page).to have_no_css('[aria-label="Applications"]', wait: 3)
    expect(page).to have_link("Account Settings", href: "#{issuer}/account?client_id=gaming")
  end

  def viewport(width)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844,
      deviceScaleFactor: 1, mobile: width < 500)
  end
end
