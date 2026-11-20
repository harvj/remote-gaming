require "rails_helper"
require Rails.root.join("db/build/base")
require Rails.root.join("db/build/games/modern_art")

RSpec.describe "Modern Art tabletop replay", type: :system do
  it "shares card faces across live and historical boards without exposing other hands or enabling gameplay in replay" do
    GameBuild::ModernArt.()
    game = Game.find_by!(key: "modern_art")
    table = GameSession::Create.!(game).subject
    %w[Alex Inez Morgan].each { |name| Player::Create.!(create(:user, name: name, password: "fixture-password"), session: table) }
    random = Random.new(411)
    allow_any_instance_of(SessionDeck).to receive(:next_card) do |deck|
      deck.cards.undealt.order(:id).to_a.sample(random: random)
    end
    srand(411)
    game.play_class.(table, table.players.first.user)
    table.reload
    player = table.current_player
    viewer = player.user
    card = player.cards.active.find { |item| item.card.value != "double" }
    hidden_ids = table.players.where.not(id: player.id).flat_map { |seat| seat.cards.active.ids }
    before = table.frames.checkpoints.last
    card.play
    played = table.frames.engine_events.find_by!(action: "card_played")
    after = table.frames.checkpoints.last

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 1250, deviceScaleFactor: 1, mobile: false)
    visit login_path
    fill_in "user_username", with: viewer.username
    fill_in "user_password", with: "fixture-password"
    click_button "Log In"
    expect(page).to have_css("main[aria-label=Games]")
    visit game_session_path(table.uid)

    board = "section[aria-label='Modern Art tabletop']"
    auction = "section[aria-label='Auction table']"
    face = "[data-card-id='#{card.id}']"
    within(board) do
      expect(page).to have_css("#{auction} #{face}", text: "#{card.card.name.titleize}")
      expect(page).to have_css("#{face} .auction-type", text: card.card.value.titleize)
      expect(page).to have_css("#{face} .emblem :is(.fa-#{card.card.icon_class}, [data-icon])")
      expect(page).to have_no_css(hidden_ids.map { |id| "[data-card-id='#{id}']" }.join(","))
    end
    color = find("#{auction} #{face} .artist").evaluate_script("this.closest('[data-card-id]').style.getPropertyValue('--artist').trim()")
    palette = { "yellow" => "#d1d322", "light-green" => "#5be67e", "dark-pink" => "#ff0000",
      "light-purple" => "#c0afef", "light-brown" => "#d7ae85" }
    expect(color).to eq(palette.fetch(card.card.color))
    screenshot("live-desktop")

    visit session_replay_path(table.uid, frame: after.sequence)
    within(board) do
      expect(page).to have_css("#{auction} #{face}")
      expect(page).to have_no_css("button[data-card-id]")
      expect(page).to have_no_css(hidden_ids.map { |id| "[data-card-id='#{id}']" }.join(","))
    end
    expect(find("#{auction} #{face} .artist").evaluate_script("this.closest('[data-card-id]').style.getPropertyValue('--artist').trim()")).to eq(color)
    screenshot("replay-checkpoint-desktop")

    visit session_replay_path(table.uid, frame: before.sequence)
    expect(page).to have_no_css("#{auction} #{face}")
    expect(page).to have_css("#{board} [aria-label='#{viewer.name}’s hand'] #{face}")
    fill_in "Frame", with: played.sequence
    click_button "Go"
    expect(page).to have_css("#{auction} #{face}")
    expect(page).to have_no_css("#{board} [aria-label='#{viewer.name}’s hand'] #{face}")
    expect(find("#{board} .seat.current")).to have_text(viewer.name)
    expect(page).to have_text("card played (engine)", exact: false)
    screenshot("replay-intermediate-desktop")

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(390)
    expect(page).to have_css("#{auction} #{face}")
    screenshot("replay-intermediate-mobile")

    game.play_class.(table, table.players.find_by!(table_captain: true).user)
    transition = table.frames.engine_events.find_by!(action: "season_two")
    visit session_replay_path(table.uid, frame: transition.sequence)
    expect(page).to have_css("#{board} h3", text: "Season Two")
    expect(page).to have_no_css("#{auction} #{face}")
    expect(page).to have_css("section[aria-label='Played paintings'] #{face}")
    click_button "Next"
    expect(page).to have_css("#{board} h3", text: "Season Two")
    expect(page).to have_text("card dealt (engine)")

  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def screenshot(name)
    return unless ENV["REPLAY_SCREENSHOTS"]

    page.evaluate_async_script("document.fonts.ready.then(arguments[0])")
    page.save_screenshot(File.join(ENV.fetch("REPLAY_SCREENSHOTS"), "#{name}.png"))
  end
end
