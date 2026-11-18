require "rails_helper"

RSpec.describe "Session joining", type: :system do
  include Warden::Test::Helpers

  let(:game) { create(:game, :cards) }
  let(:session) { GameSession::Create.!(game).subject }

  after { Warden.test_reset! }

  it "refreshes a second browser when a player joins and reconnects" do
    spectator = create(:user)
    player = create(:user)

    using_session("spectator") do
      login_as(spectator, scope: :user)
      visit game_session_path(session.uid)
      expect(page).to have_text("0 players")
    end

    using_session("player") do
      login_as(player, scope: :user)
      visit game_session_path(session.uid)
      click_button "Join"
      expect(page).to have_text("1 player")
      expect(page).to have_button("Leave")
    end

    using_session("spectator") do
      expect(page).to have_text("1 player")
    end

    using_session("player") do
      visit root_path
      visit game_session_path(session.uid)
      expect(page).to have_button("Leave")
      expect(page).to have_text("1 player")
    end
  end
end
