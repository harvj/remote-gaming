require "rails_helper"

RSpec.describe "Modern Art tabletop replay", type: :system do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  it "shows the recorded final cash for kesir-ample-gifa-ghnw on the completed tabletop and replay fallback" do
    game = create(:game, :modern_art)
    table = game.sessions.create!(uid: "kesir-ample-gifa-ghnw", state: "completed")
    names = [ "Jim Harvey", "Robert McMurray", "Bob McMurray" ]
    scores = [ 543, 658, 586 ]
    members = names.map { |name| create(:user, name: name) }
    players = members.map.with_index do |member, index|
      table.all_players.create!(user: member, game_id: game.id, action_phase: "idle",
        turn_order: index + 1, score: scores[index], winner: index == 1)
    end
    login_as(members.first, scope: :user)

    [ game_session_path(table.uid), session_replay_path(table.uid) ].each do |path|
      visit path
      within("ol[aria-label='Recorded final cash standings']") do
        expect(all("li").map { |row| row.text.squish }).to eq([ "Jim Harvey $543k", "Robert McMurray · Winner $658k", "Bob McMurray $586k" ])
      end
      expect(page).to have_css(".hand-heading strong", text: "Final cash · $543k")
      expect(page).to have_text("Bid history Not recorded")
      expect(page).to have_no_text("Final cash standings Not recorded")
      players.each_with_index do |player, index|
        within(find(".seats article", text: names[index])) do
          expect(page).to have_css(".badge.black", exact_text: scores[index].to_s)
          expect(page).to have_text("Final cash $#{scores[index]}k")
        end
        expect(player.reload.score).to eq(scores[index])
      end
    end
  end

  it "shares card faces across live and historical boards without exposing other hands or enabling gameplay in replay" do
    game = create(:game, :modern_art)
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
    login_as(viewer, scope: :user)
    visit game_session_path(table.uid)

    board = "section[aria-label='Modern Art tabletop']"
    auction = "section[aria-label='Auction table']"
    face = "[data-card-id='#{card.id}']"
    expect(page).to have_text("Not recorded")
    click_button "Game Rules"
    expect(page).to have_css("dialog[open] h2", text: "Modern Art rules")
    find('dialog button[aria-label="Close game rules"]').click
    within(board) do
      expect(page).to have_css("#{auction} #{face}", text: "#{card.card.name.titleize}")
      expect(page).to have_css("#{face} .auction-type", text: card.card.value.titleize)
      expect(page).to have_css("#{face} .emblem :is(.fa-#{card.card.icon_class}, [data-icon])")
      expect(page).to have_no_css(hidden_ids.map { |id| "[data-card-id='#{id}']" }.join(","))
    end
    palette = {
      "yellow" => [ 209, 211, 34 ], "light-green" => [ 91, 230, 126 ], "dark-pink" => [ 255, 0, 0 ],
      "light-purple" => [ 192, 175, 239 ], "light-brown" => [ 215, 174, 133 ]
    }
    artist = palette.fetch(card.card.color)
    live_style = card_style(find("#{auction} #{face}"))
    expect(live_style).to eq(expected_card_style(artist))
    expect(all("#{board} .swatch").map { |swatch| swatch.evaluate_script("getComputedStyle(this).backgroundColor") })
      .to eq(palette.values.map { |rgb| "rgb(#{rgb.join(', ')})" })
    screenshot("live-desktop")

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    expect(page).to have_css(".session-title .name", exact_text: table.uid)
    expect(page.evaluate_script(<<~JS)).to eq([ 390, true, true ])
      (() => {
        const title = document.querySelector(".session-title");
        const status = title.nextElementSibling.getBoundingClientRect();
        const range = document.createRange();
        range.selectNodeContents(title.querySelector(".name"));
        const lines = Array.from(range.getClientRects());
        return [document.documentElement.scrollWidth, lines.length > 1,
          lines.every(line => line.left >= 0 && line.right <= status.left)];
      })()
    JS
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 1250, deviceScaleFactor: 1, mobile: false)

    board = "article[aria-label='Modern Art tabletop']"
    visit session_replay_path(table.uid, frame: after.sequence)
    click_button "Game Rules"
    expect(page).to have_css("dialog[open] h2", text: "Modern Art rules")
    find('dialog button[aria-label="Close game rules"]').click
    expect(page).to have_text("Not recorded")
    within(board) do
      expect(page).to have_css("#{auction} #{face}")
      expect(page).to have_no_css("button[data-card-id]")
      expect(page).to have_no_css(hidden_ids.map { |id| "[data-card-id='#{id}']" }.join(","))
    end
    expect(card_style(find("#{auction} #{face}"))).to eq(live_style)
    screenshot("replay-bids-not-recorded-desktop")
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    screenshot("replay-bids-not-recorded-mobile")
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1440, height: 1250, deviceScaleFactor: 1, mobile: false)
    screenshot("replay-checkpoint-desktop")

    visit session_replay_path(table.uid, frame: before.sequence)
    expect(page).to have_no_css("#{auction} #{face}")
    expect(page).to have_css("#{board} .hand #{face}")
    fill_in "Frame", with: played.sequence
    click_button "Go"
    expect(page).to have_css("#{auction} #{face}")
    expect(page).to have_no_css("#{board} .hand #{face}")
    expect(find("#{board} .seats article.active")).to have_text(viewer.name)
    expect(page).to have_text("card played (engine)", exact: false)
    screenshot("replay-intermediate-desktop")

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(390)
    expect(page).to have_css("#{auction} #{face}")
    page.execute_script("window.scrollTo(0, 120)")
    expect(page).to have_css("main[data-shell-fading]")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('main')).maskImage")).to include("linear-gradient")
    expect(page.evaluate_script("document.querySelector('header').getBoundingClientRect().top")).to eq(0)
    replay_card = find("#{auction} #{face}")
    expect(replay_card.evaluate_script(<<~JS)).to be >= 24
      this.getBoundingClientRect().top - document.querySelector('header').getBoundingClientRect().bottom
    JS
    expect(card_style(replay_card)).to eq(live_style)
    screenshot("replay-intermediate-mobile")

    game.play_class.(table, table.players.find_by!(table_captain: true).user)
    transition = table.frames.engine_events.find_by!(action: "season_two")
    visit session_replay_path(table.uid, frame: transition.sequence)
    expect(page).to have_css("#{board} [aria-current='step']", text: "Season 2")
    expect(page).to have_no_css("#{auction} #{face}")
    find("summary", text: "Recorded paintings").click
    expect(page).to have_css("details[aria-label='Played paintings'] #{face}")
    click_button "Next"
    expect(page).to have_css("#{board} [aria-current='step']", text: "Season 2")
    expect(page).to have_text("card dealt (engine)")

  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def card_style(card)
    page.evaluate_script(<<~JS, card)
      ((element) => {
        const canvas = document.createElement("canvas");
        canvas.width = canvas.height = 1;
        const context = canvas.getContext("2d");
        const rgba = (color) => {
          context.clearRect(0, 0, 1, 1);
          context.fillStyle = color;
          context.fillRect(0, 0, 1, 1);
          return Array.from(context.getImageData(0, 0, 1, 1).data);
        };
        const style = getComputedStyle(element);
        const ancestors = [];
        for (let node = element; node; node = node.parentElement) ancestors.push(node);
        const layers = ancestors.map(node => getComputedStyle(node));
        return {
          accent: rgba(style.borderTopColor),
          face: rgba(style.backgroundColor),
          emblem: rgba(getComputedStyle(element.querySelector(".emblem")).backgroundColor),
          opaque: layers.every(layer => layer.opacity === "1"),
          unfiltered: layers.every(layer => layer.filter === "none" && layer.backdropFilter === "none"),
          unblended: layers.every(layer => layer.mixBlendMode === "normal"),
          locallyUnmasked: layers.every((layer, index) => layer.maskImage === "none" || ancestors[index].matches("main[data-shell-fading]")),
        };
      })(arguments[0])
    JS
  end

  def expected_card_style(artist)
    paper = [ 255, 253, 246 ]
    mix = ->(weight) { artist.zip(paper).map { |channel, base| (channel * weight + base * (1 - weight)).round(half: :even) } + [ 255 ] }
    { "accent" => artist + [ 255 ], "face" => mix.call(0.2), "emblem" => mix.call(0.5),
      "opaque" => true, "unfiltered" => true, "unblended" => true, "locallyUnmasked" => true }
  end

  def screenshot(name)
    return unless ENV["REPLAY_SCREENSHOTS"]

    page.evaluate_async_script("document.fonts.ready.then(arguments[0])")
    page.save_screenshot(File.join(ENV.fetch("REPLAY_SCREENSHOTS"), "#{name}.png"))
  end
end
