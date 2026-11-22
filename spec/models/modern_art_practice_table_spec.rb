require "rails_helper"

RSpec.describe ModernArtPracticeTable do
  let(:game) { create(:game, :modern_art) }
  let(:owner) { create(:user) }

  it "plays four seasons reproducibly and exercises every auction through the same commands" do
    phases = []
    seasons = []
    [ 411, 73, 140 ].each do |seed|
      table = described_class.open!(owner, game, seed: seed)
      expect(table.position.fetch("deck").size).to eq(40)
      expect(table.owner_view.fetch(:hand).size).to eq(10)
      expect(table.owner_view.fetch(:players).drop(1).any? { |player| player.key?(:cash) }).to be(false)
      250.times do
        rules = Games::ModernArt::PracticeRules.new(table.position)
        phase = rules.state.fetch("phase")
        phases << phase
        break if phase == "complete"

        choice = if phase == "scoring"
          seasons << rules.state.fetch("season")
          [ "advance", nil ]
        else
          Games::ModernArt::PracticeOpponent.choose(rules, 0)
        end
        expect(choice).to be_present
        table.act!(table.commands.size, *choice)
      end
      phases.concat(table.commands.select { |_, action, _| action == "play" }.map do |_, _, id|
        table.position.fetch("cards").fetch(id.to_s).fetch("kind")
      end)
      expect(table.reload.position.fetch("phase")).to eq("complete")
      expect(table.replay).to eq(table.position)
      expect(table.position.fetch("cash")).to all(be >= 0)
      expect(table.owner_view.fetch(:players)).to all(include(:cash))
    end
    expect(phases).to include("double", "fixed", "open", "sealed", "once_around", "scoring")
    expect(seasons).to include(1, 2, 3, 4)
  end

  it "rejects stale revisions and illegal card submissions without appending commands" do
    table = described_class.open!(owner, game, seed: 411)
    id = table.owner_view.fetch(:hand).first.fetch("id")
    expect { table.act!(0, "play", -1) }.to raise_error(Games::ModernArt::PracticeRules::IllegalCommand)
    expect(table.reload.commands).to be_empty
    table.act!(0, "play", id)
    current = table.reload.commands
    expect { table.act!(0, "play", id) }.to raise_error(ModernArtPracticeTable::StalePosition)
    expect(table.reload.commands).to eq(current)
  end

  it "keeps sealed bids private until all seats commit and gives the seller priority on a tie" do
    table = described_class.open!(owner, game, seed: 411)
    rules = Games::ModernArt::PracticeRules.new(table.position)
    id = table.position.fetch("cards").values.find { |card| card.fetch("kind") == "sealed" }.fetch("id")
    table.position.fetch("hands")[0] << id
    rules.command(0, "play", id)
    rules.command(1, "bid", 12)
    expect(rules.projection(0).fetch(:auction)).not_to include("bids", "leader")
    expect(rules.projection(0).fetch(:recent)).not_to include(a_hash_including("amount" => 12))
    rules.command(2, "bid", 12)
    rules.command(0, "bid", 12)
    expect(rules.state.fetch("cash")).to eq([ 88, 100, 100 ])
    expect(rules.state.fetch("holdings").first).to include(id)
  end
end
