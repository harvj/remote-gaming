require "rails_helper"

RSpec.describe "Modern Art interactive replay and branching", type: :system do
  around do |example|
    protection = ActionController::Base.allow_forgery_protection
    origin_check = ActionController::Base.forgery_protection_origin_check
    ActionController::Base.allow_forgery_protection = true
    ActionController::Base.forgery_protection_origin_check = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = protection
    ActionController::Base.forgery_protection_origin_check = origin_check
  end

  it "navigates replay, branches at a checkpoint, and plays an alternative through a new dummy browser" do
    owner = create(:user)
    game = create(:game, :modern_art)
    table = GameSession::Create.!(game, experimental: true, experiment_owner: owner).subject
    Player::Create.!(owner, session: table)
    2.times { Player::Create.!(create(:user, dummy: true), session: table) }
    game.play_class.(table, owner)
    if table.reload.current_player.user == owner
      table.current_player.cards.active.find { |card| card.card.value != "double" }.play
    end
    fork = table.frames.checkpoints.last
    source_turn = table.reload.current_player
    expect(source_turn.user).to be_dummy
    paintings_at_fork = table.cards.played.count
    first_card = source_turn.cards.active.find(&:playable?)
    first_card.play
    original_frames = table.frames.order(:sequence).pluck(:id)

    issuer = "https://auth.fixture.test"
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REMOTE_GAMING_OIDC_ISSUER").and_return(issuer)
    allow(ExperimentalAccess).to receive(:enabled?).and_return(true)
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    provider = instance_double(CanonicalAuth)
    identity = AuthIdentity.create!(user: owner, issuer: issuer, subject: "owner", evidence_reference: "fixture")
    allow(CanonicalAuth).to receive(:new).and_return(provider)
    allow(provider).to receive(:authenticate).with(nil, state: "fixture", code: "fixture").and_return([ identity, CanonicalAuth::MFA ])

    visit "/auth/callback?state=fixture&code=fixture"
    visit game_session_path(table.uid)
    click_link "Replay history"
    expect(page).to have_text("Frame #{original_frames.size} of #{original_frames.size}")
    click_button "Beginning"
    expect(page).to have_text("Frame 1 of")
    expect(page).to have_no_button("Create private branch")
    click_button "Next"
    expect(page).to have_text("Frame 2 of")
    click_button "Previous"
    expect(page).to have_text("Frame 1 of")
    click_button "End"
    expect(page).to have_text("Frame #{original_frames.size} of")
    fill_in "Frame", with: fork.sequence
    click_button "Go"
    expect(page).to have_text("Frame #{fork.sequence} of")
    click_button "Create private branch"

    expect(page).to have_text("Private experimental branch")
    branch = GameSession.find_by!(parent_session: table)
    turn = branch.current_player
    alternate = turn.cards.active.select(&:playable?).find { |card| card.card_id != first_card.card_id }
    expect(alternate).to be_present
    expect(turn.user).to be_dummy
    find("form[action='#{rotate_session_dummy_path(branch.uid, turn.id)}']").click_button("Issue new code")
    credential = find("#dummy-credential").text
    using_session(:branch_dummy) do
      visit dummy_login_path
      fill_in "One-time access code", with: credential
      click_button "Open private table"
      expect(page).to have_text("Private experimental branch")
      find("button[data-card-id='#{alternate.id}']").click
      expect(page).to have_no_css("button[data-card-id='#{alternate.id}']:enabled")
      visit session_replay_path(table.uid)
      expect(page).to have_no_text("Modern Art replay")
    end
    click_link "Return to the private table"

    click_link "Replay history"
    click_button "Compare with original fork"
    within("section[aria-label='Timeline comparison']") do
      expect(page).to have_text("#{paintings_at_fork} #{paintings_at_fork == 1 ? 'painting' : 'paintings'} played")
      expect(page).to have_text("#{paintings_at_fork + 1} #{paintings_at_fork.zero? ? 'painting' : 'paintings'} played")
    end
    click_link "Original timeline"
    expect(page).to have_text("Frame #{fork.sequence} of #{original_frames.size}")
    expect(table.frames.order(:sequence).pluck(:id)).to eq(original_frames)
    expect(branch.frames.engine_events.where(action: "card_played").last.subject_id).to eq(alternate.id)
  end
end
