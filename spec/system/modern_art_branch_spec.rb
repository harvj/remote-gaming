require "rails_helper"

RSpec.describe "Modern Art historical branch replay", type: :system do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  it "navigates and compares an existing branch with its original fork" do
    owner = create(:user)
    game = create(:game, :modern_art)
    players = [ owner, create(:user, dummy: true), create(:user, dummy: true) ]
    source = GameSession::Create.!(game, experimental: true, experiment_owner: owner).subject
    players.each { |user| Player::Create.!(user, session: source) }
    game.play_class.(source, owner)
    fork = source.frames.checkpoints.last
    branch = GameSession::Create.!(game, experimental: true, experiment_owner: owner,
      parent_session: source, fork_frame: fork, branch_rules_version: 1).subject
    players.each { |user| Player::Create.!(user, session: branch) }
    game.play_class.(branch, owner)
    first_card = branch.reload.current_player.cards.active.find(&:playable?)
    first_card.play
    original_frames = source.frames.order(:sequence).pluck(:id)
    last = branch.frames.maximum(:sequence)

    login_as(owner, scope: :user)
    visit game_session_path(branch.uid)
    expect(page).to have_no_button("Add dummy player")
    click_link "Replay history"
    expect(page).to have_text("Frame #{last} of #{last}")
    click_button "Beginning"
    expect(page).to have_text("Frame 1 of")
    click_button "Next"
    expect(page).to have_text("Frame 2 of")
    click_button "Previous"
    expect(page).to have_text("Frame 1 of")
    click_button "End"
    expect(page).to have_text("Frame #{last} of")
    expect(page).to have_no_button("Create private branch")
    click_button "Compare with original fork"
    within("section[aria-label='Timeline comparison']") do
      expect(page).to have_text("0 paintings played")
      expect(page).to have_text("1 painting played")
    end
    click_link "Original timeline"
    expect(page).to have_text("Frame #{fork.sequence} of #{original_frames.size}")
    expect(source.frames.order(:sequence).pluck(:id)).to eq(original_frames)
    expect(branch.frames.engine_events.where(action: "card_played").last.subject_id).to eq(first_card.id)
  end
end
