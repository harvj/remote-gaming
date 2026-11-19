require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "allows a consumed ticket only for its active seat and rejects a revoked connection on its next delivery" do
    allow(CanonicalAuth).to receive(:enabled?).and_return(true)
    real = create(:user)
    game = create(:game, :modern_art)
    table = GameSession::Create.!(game, experimental: true, experiment_owner: real).subject
    Player::Create.!(real, session: table)
    dummy = create(:user, dummy: true)
    player = Player::Create.!(dummy, session: table).subject
    access = player.create_dummy_access!(expires_at: Time.current)
    _, ticket = DummyAccess.redeem!(access.issue!)
    other = GameSession::Create.!(game).subject

    connect "/cable", session: { dummy_browser: ticket }
    expect(connection.current_user).to eq(dummy)
    expect(connection.allowed_at_table?(table)).to be_truthy
    expect(connection.allowed_at_table?(other)).to be_falsey
    access.revoke!
    expect(connection.allowed_at_table?(table)).to be_falsey
    expect { connect "/cable", session: { dummy_browser: ticket } }.to have_rejected_connection
  end
end
