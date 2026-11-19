class GameCatalogAudit
  def self.call
    require Rails.root.join("db/build/base")
    require Rails.root.join("db/build/games/modern_art")
    require Rails.root.join("db/build/games/pandemic")

    errors = []
    modern_art = Game.find_by(key: "modern_art")
    pandemic = Game.find_by(key: "pandemic")

    if modern_art
      expected = Play::ModernArt::DECKS.flat_map do |artists|
        artists.flat_map { |artist, auctions| auctions.keys.map { |type| [ artist.to_s, type.to_s ] } }
      end
      errors << "Modern Art card definitions are missing, duplicated, or unexpected" unless
        modern_art.cards.pluck(:name, :value).tally == expected.tally
      errors.concat(game_errors(modern_art, [ 3, 5 ], GameBuild::ModernArt::ROLES))
    else
      errors << "Missing Modern Art game"
    end

    if pandemic
      player_cards = GameBuild::Pandemic::CITIES + GameBuild::Pandemic::SPECIALS
      expected = player_cards.map { |card| [ "player", card.fetch(:name), card.fetch(:value) ] }
      expected.concat(GameBuild::Pandemic::CITIES.map { |card| [ "infection", card.fetch(:name), "infection" ] })
      expected << [ "epidemic", "epidemic", "epidemic" ]
      errors << "Pandemic card definitions are missing, duplicated, or unexpected" unless
        pandemic.cards.pluck(:key, :name, :value).tally == expected.tally
      errors.concat(game_errors(pandemic, Play::Pandemic::INIT_DEAL_COUNTS.keys.map(&:to_i).minmax, GameBuild::Pandemic::ROLES))
    else
      errors << "Missing Pandemic game"
    end

    if GameSession.where(game_id: nil).or(GameSession.where.not(game_id: Game.select(:id))).exists?
      errors << "A historical session has no matching game"
    end
    errors
  end

  def self.game_errors(game, players, roles)
    errors = []
    errors << "#{game.name} player bounds differ" unless [ game.min_players, game.max_players ] == players
    errors << "#{game.name} roles are missing, duplicated, or unexpected" unless game.roles.pluck(:name).tally ==
      roles.pluck(:name).tally
    errors
  end
  private_class_method :game_errors
end
