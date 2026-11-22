class ModernArtPracticeTable < ApplicationRecord
  class StalePosition < StandardError; end

  belongs_to :owner, class_name: "User"

  NAMES = [ "You", "Maya Chen", "Daniel Reyes" ].freeze
  MAX_AUTOMATED_ACTIONS = 300

  def self.open!(owner, game, seed: SecureRandom.random_number(2**32), human_session: nil)
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
    if human_session
      setup["mode"] = "human"
      return create!(owner: owner, uid: human_session.uid, setup: setup, position: {})
    end

    table = new(owner: owner, uid: SecureRandom.hex(16), setup: setup, position: rules_for(setup).state)
    table.save!
    table
  end

  def self.rules_for(setup)
    Games::ModernArt::PracticeRules.start(setup.fetch("cards"),
      seed: setup.fetch("seed"), first_seat: setup.fetch("first_seat"),
      seat_count: setup.fetch("participants", NAMES).length, recorded: setup["mode"] == "human")
  end

  def human? = setup["mode"] == "human"

  def begin_human!(players)
    with_lock do
      raise Games::ModernArt::PracticeRules::IllegalCommand unless human? && position.empty? && players.size.between?(3, 5)
      setup["participants"] = players.map { |player| { "user_id" => player.user_id, "name" => player.user.name } }
      self.position = self.class.rules_for(setup).state
      save!
    end
  end

  def seat_for(user)
    setup.fetch("participants").index { |member| member.fetch("user_id") == user.id }
  end

  def act!(expected_revision, action, value, seat: 0)
    with_lock do
      raise StalePosition unless expected_revision == commands.length

      rules = Games::ModernArt::PracticeRules.new(position)
      apply(rules, seat, action, value)
      if human?
        save!
        return
      end
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

  def replay(revision = commands.length)
    rules = self.class.rules_for(setup)
    commands.first(revision).each { |command| rules.command(*command.first(3)) }
    rules.state
  end

  def owner_view
    numbered_projection(0, commands.length).merge(names: NAMES)
  end

  def human_view(user, revision: nil)
    seat = seat_for(user)
    raise ActiveRecord::RecordNotFound if seat.nil?

    names = setup.fetch("participants").map { |member| member.fetch("name") }
    names[seat] = "You"
    rules = Games::ModernArt::PracticeRules.new(revision ? replay(revision) : position)
    settlements = rules.state.fetch("settlements")
    settled_auctions = settlements.pluck("auction").to_set
    visible_commands = commands.first(revision || commands.length).each_with_index.filter_map do |entry, index|
      bidder, action, amount, auction, phase = entry
      next unless %w[bid pass buy price].include?(action)
      next if phase == "sealed" && !settled_auctions.include?(auction)

      { sequence: index + 1, seat: bidder, action: action, amount: amount, auction: auction }
    end
    numbered_projection(seat, revision || commands.length).merge(names: names, viewerSeat: seat,
      bidHistory: visible_commands, settlements: settlements)
  end

  private

  def numbered_projection(seat, revision)
    rules = self.class.rules_for(setup)
    hidden = []
    history = commands.first(revision).each_with_index.map do |entry, index|
      actor, action, value = entry
      sealed = rules.state.fetch("phase") == "sealed" && action == "bid"
      rules.command(actor, action, value)
      event = { number: index + 1, action: action, seat: actor, notes: rules.command_notes }
      if sealed
        event[:amount] = value
        hidden << event
        if rules.state.fetch("phase") == "sealed"
          event[:sealed] = true
        else
          hidden.each { |bid| bid.delete(:sealed) }
          hidden.clear
        end
      end
      event
    end
    history.each do |event|
      next unless event[:sealed]

      event.delete(:amount)
      event.delete(:seat)
    end
    rules.projection(seat).merge(revision: revision, recent: history.last(8), actionHistory: history)
  end

  def apply(rules, seat, action, value)
    phase = rules.state.fetch("phase")
    rules.command(seat, action, value)
    entry = [ seat, action, value ]
    entry.concat([ rules.state.fetch("auction_number"), phase ]) if human?
    commands << entry
  end
end
