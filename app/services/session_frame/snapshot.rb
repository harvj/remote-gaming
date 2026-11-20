class SessionFrame::Snapshot
  SESSION_FIELDS = %w[id uid game_id created_at state current_player_id started_at completed_at special_game_phase special_game_phase_timer].freeze
  PLAYER_FIELDS = %w[id user_id role_id action_phase action_phase_revert next_player_id turn_order score winner moderator removed_at table_captain].freeze
  CARD_FIELDS = %w[id card_id player_id session_deck_id dealt_at played_at discarded_at].freeze
  CATALOG_FIELDS = %w[id key name value color icon_class name_sort value_sort].freeze

  def self.call(session)
    {
      "session" => fields(session, SESSION_FIELDS + (session.experimental? ? %w[experimental experiment_owner_id] : [])),
      "game" => session.game.slice("id", "key", "name", "min_players", "max_players").merge("rules_version" => session.play_class::RULES_VERSION),
      "players" => session.all_players.order(:id).includes(:role, :user).map do |player|
        fields(player, PLAYER_FIELDS).merge(
          "identity" => player.user.slice("id", "username", "name").tap { |identity| identity["kind"] = "dummy" if player.user.dummy? },
          "role" => player.role&.slice("id", "name", "color", "icon_class")
        )
      end,
      "decks" => session.decks.order(:id).map { |deck| deck.slice("id", "key") },
      "cards" => session.cards.order(:id).includes(:card).map do |card|
        fields(card, CARD_FIELDS).merge("definition" => card.card.slice(*CATALOG_FIELDS))
      end
    }.as_json
  end

  def self.fields(record, keys)
    record.slice(*keys).transform_values do |value|
      value.is_a?(Time) ? value.iso8601(6) : value
    end
  end
  private_class_method :fields
end
