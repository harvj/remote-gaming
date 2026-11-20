require "rails_helper"

RSpec.describe "Modern Art multiplayer", type: :system do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  let(:game) { create(:game, :modern_art) }
  let(:table) { GameSession::Create.!(game).subject }


  def play_next(table)
    player = table.current_player
    candidates = player.cards.active.select(&:playable?)
    played = table.played_card_counts_by_state(table.state).to_h { |item| [ item.name, item.count.to_i ] }
    card = candidates.max_by { |item| [ played.fetch(item.card.name, 0), item.card.value == "double" ? 0 : 1, -item.id ] }
    revision = table.frames.maximum(:sequence)

    using_session(player.user_id) do
      expect(page).to have_css("[data-revision='#{revision}']")
      if card
        find("button[data-card-id='#{card.id}']:enabled").click
      else
        click_button "Pass"
      end
      expect(page).to have_no_css("[data-revision='#{revision}']")
    end
  end

  it "joins three players, plays four seasons, reports a physical payment and replays the result" do
    members = Array.new(3) { create(:user) }
    members.each_with_index do |member, index|
      using_session(member.id) do
        login_as(member, scope: :user)
        visit game_session_path(table.uid)
        click_button "Join"
        count = index + 1
        expect(page).to have_text("#{count} #{count == 1 ? 'player' : 'players'}")
      end
    end

    play_game(table, members)
  end

  it "plays and replays a private experiment from one real browser and two separately redeemed dummy browsers" do
    owner = create(:user)
    issuer = "https://auth.fixture.test"
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    allow(ExperimentalAccess).to receive(:enabled?).and_return(true)
    identity = AuthIdentity.create!(user: owner, issuer: issuer, subject: "owner", evidence_reference: "fixture")
    provider = instance_double(CanonicalAuth)
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    allow(provider).to receive(:authenticate).with(nil, state: "fixture", code: "fixture").and_return([ identity, CanonicalAuth::MFA ])

    experiment = nil
    seats = []
    using_session(owner.id) do
      visit "/auth/callback?state=fixture&code=fixture"
      visit game_path(game.key)
      click_button "Create private experiment"
      expect(page).to have_text("Private experiment")
      experiment = GameSession.find_by!(experiment_owner: owner)
      2.times do
        click_button "Add dummy player"
        secret = find("#dummy-credential").text
        seats << experiment.players.joins(:dummy_access).order(:id).last.user
        using_session(seats.last.id) do
          visit dummy_login_path
          fill_in "One-time access code", with: secret
          click_button "Open private table"
          expect(page).to have_text("Private experiment")
        end
        click_link "Return to the private table"
      end
    end
    play_game(experiment, [ owner, *seats ])
    expect(experiment.frames.where(actor_kind: "dummy", action: "card_played")).to exist
    expect(experiment.frames.observations.pluck(:actor_kind)).to eq([ "person", "person" ])
  end

  def play_game(table, members)
    using_session(members.first.id) do
      expect(page).to have_text("3 players")
      click_button "Start with 3 players"
      expect(page).to have_text("10 cards in hand")
      expect(page).to have_text("Season One")
    end

    starting_player = table.reload.current_player
    reconnecting = members.find { |member| member.id != starting_player.user_id }
    using_session(reconnecting.id) { visit(reconnecting.dummy? ? dummy_login_path : root_path) }
    play_next(table.reload)
    using_session(reconnecting.id) do
      visit game_session_path(table.uid)
      expect(page).to have_text("Season One")
      expect(page).to have_text("10 cards in hand")
    end

    using_session(members.first.id) do
      click_button "Record payment"
      select members.first.name, from: "observation-payer_id"
      select members.last.name, from: "observation-payee_id"
      fill_in "observation-amount", with: 12
      click_button "Save report"
      expect(page).to have_text("Participant report")
      click_button "Correct"
      fill_in "observation-amount", with: 14
      click_button "Save report"
      expect(page).to have_text("Corrected report")
      expect(page).to have_text("14")
    end

    66.times do
      break if table.reload.completed?

      play_next(table)
    end
    expect(table.reload).to be_completed
    expect(table.transition_actions).to eq(%w[started season_one season_two season_three season_four completed])

    members.each_with_index do |member, index|
      using_session(member.id) do
        expect(page).to have_text("Completed")
        fill_in "Your score", with: 30 + index
        click_button "Submit"
        expect(page).to have_no_field("Your score")
        expect(page).to have_text("play history")
      end
    end

    expect(table.reload.winner.user).to eq(members.last)
    expect(SessionFrame::Replay.call(table.frames.order(:sequence))).to eq(SessionFrame::Snapshot.call(table))
  end
end
