class GameBuild::ModernArt < GameBuild::Base
  CARD_ATTRS = {
    lite_metal:   { color: 'yellow' },
    yoko:         { color: 'light-green' },
    cristin_p:    { color: 'dark-pink' },
    karl_gitter:  { color: 'light-purple' },
    krypto:       { color: 'light-brown' },
    fixed:        { icon_class: 'dollar-sign' },
    open:         { icon_class: 'arrows-alt' },
    sealed:       { icon_class: 'circle' },
    once_around:  { icon_class: 'redo' },
    double:       { icon_class: 'equals' }
  }.freeze

  ROLES = [
    { name: 'berlin' },
    { name: 'bilbao' },
    { name: 'new york' },
    { name: 'paris' },
    { name: 'tokyo' }
  ]

  def add_game
    game = create_game(name: 'Modern Art', key: 'modern_art', min_players: 3, max_players: 5)

    %w[lite_metal yoko cristin_p karl_gitter krypto].each_with_index do |name, name_sort|
      %w[double sealed open once_around fixed].each_with_index do |value, value_sort|
        create_card(
          game_id: game.id,
          name: name,
          name_sort: name_sort,
          value: value,
          value_sort: value_sort,
          color: CARD_ATTRS[name.to_sym][:color],
          icon_class: CARD_ATTRS[value.to_sym][:icon_class],
          key: 'default'
        )
      end
    end

    ROLES.each do |params|
      create_role(params.merge(game_id: game.id))
    end
  end
end
