require "rails_helper"

RSpec.describe GameSessionChannel, type: :channel do
  let(:game) { create(:game, :cards) }
  let(:user) { create(:user) }
  let(:session) { new_session }

  it "rejects an unauthenticated cable connection" do
    stub_connection current_user: nil
    subscribe(uid: session.uid)
    expect(subscription).to be_rejected
  end

  it "allows an authenticated invitee to receive waiting lobby invalidations" do
    stub_connection current_user: user
    subscribe(uid: session.uid)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(session)
  end

  it "limits a started session subscription to its own members" do
    add_player
    session_proceed
    stub_connection current_user: create(:user)
    subscribe(uid: session.uid)
    expect(subscription).to be_rejected

    stub_connection current_user: user
    subscribe(uid: session.uid)
    expect(subscription).to have_stream_for(session)
  end

  it "rejects a nonexistent session" do
    stub_connection current_user: user
    subscribe(uid: "missing")
    expect(subscription).to be_rejected
  end
end
