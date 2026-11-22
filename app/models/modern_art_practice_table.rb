class ModernArtPracticeTable < ApplicationRecord
  class StalePosition < StandardError; end

  belongs_to :owner, class_name: "User"

  NAMES = [ "You", "Maya Chen", "Daniel Reyes" ].freeze
  MAX_AUTOMATED_ACTIONS = 300

  def self.open!(owner, game, seed: SecureRandom.random_number(2**32))
    catalog = game.cards.index_by { |card| [ card.name, card.value ] }
    cards = Play::ModernArt::DECKS.first.flat_map do |artist, auctions|
      auctions.flat_map do |kind, count|
        definition = catalog.fetch([ artist.to_s, kind.to_s ])
        Array.new(count) do
          { "artist" => artist.to_s, "kind" => kind.to_s, "name" => definition.name.titleize,
            "value" => definition.value.titleize, "color" => definition.color,
            "iconClass" => definition.icon_class, "order" => definition.name_sort }
        end
      end
    end.each_with_index.map { |card, index| card.merge("id" => index + 1) }
    setup = { "seed" => seed, "first_seat" => 0, "cards" => cards }
    table = new(owner: owner, uid: SecureRandom.hex(16), setup: setup, position: rules_for(setup).state)
    table.save!
    table
  end

  def self.rules_for(setup)
    Games::ModernArt::PracticeRules.start(setup.fetch("cards"),
      seed: setup.fetch("seed"), first_seat: setup.fetch("first_seat"))
  end

  def act!(expected_revision, action, value)
    with_lock do
      raise StalePosition unless expected_revision == commands.length

      rules = Games::ModernArt::PracticeRules.new(position)
      apply(rules, 0, action, value)
      MAX_AUTOMATED_ACTIONS.times do
        automated = [ 1, 2 ].filter_map do |seat|
          choice = Games::ModernArt::PracticeOpponent.choose(rules, seat)
          [ seat, *choice ] if choice
        end.first
        unless automated
          save!
          return
        end

        apply(rules, *automated)
      end
      raise "Practice auction exceeded the automated action limit"
    end
  end

  def replay
    rules = self.class.rules_for(setup)
    commands.each { |command| rules.command(*command) }
    rules.state
  end

  def owner_view
    Games::ModernArt::PracticeRules.new(position).projection(0).merge(revision: commands.length, names: NAMES)
  end

  private

  def apply(rules, seat, action, value)
    rules.command(seat, action, value)
    commands << [ seat, action, value ]
  end
end
