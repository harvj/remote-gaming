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

  def viewport(width)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844,
      deviceScaleFactor: 1, mobile: width < 500)
  end
end
