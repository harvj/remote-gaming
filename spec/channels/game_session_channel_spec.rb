require "rails_helper"

RSpec.describe GameSessionChannel, type: :channel do
  let(:game)  { create(:game) }
  let(:user)  { create(:user) }

  let(:session) { new_session }

  before do
    stub_connection current_user: user
  end

  context "when user is not a player" do
    it "subscribes to public stream" do
      subscribe(uid: session.uid)

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from(
        "game_session:#{session.uid}:public"
      )
    end
  end

  context "when user is a player" do
    let!(:player) { add_player }

    it "subscribes to player stream" do
      subscribe(uid: session.uid)

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from(
        "game_session:#{session.uid}:#{user.username}"
      )
    end
  end
end
