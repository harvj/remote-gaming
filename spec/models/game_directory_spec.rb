require "rails_helper"
require "tempfile"

RSpec.describe GameDirectory do
  it "registers new internal and external destinations from data" do
    Tempfile.create do |file|
      file.write(<<~YAML)
        next-game:
          title: Next Game
          description: A new game.
          available: false
        independent:
          title: Independent
          description: A separately deployed game.
          available: true
          destination: https://games.example.org/
      YAML
      file.flush

      directory = described_class.new(file.path)
      expect(directory.games.map { |game| game.fetch(:slug) }).to eq(%w[independent next-game])
      expect(directory.internal_game("next-game.radioactivita.com")).to include(
        available: false, destination: "https://next-game.radioactivita.com/"
      )
      expect(directory.internal_game("independent.radioactivita.com")).to be_nil
    end
  end

  it "rejects a non-HTTPS destination" do
    Tempfile.create do |file|
      file.write(<<~YAML)
        a-game:
          title: A game
          description: A description.
          available: true
          destination: javascript:alert(1)
      YAML
      file.flush

      expect { described_class.new(file.path) }.to raise_error(ArgumentError, /Invalid directory entry/)
    end
  end
end
