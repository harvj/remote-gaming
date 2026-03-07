class GameBuild::Pandemic < GameBuild::Base
  CITIES = [
    { name: 'algiers', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'atlanta', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'baghdad', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'bangkok', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'beijing', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'bogota', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'buenos aires', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'cairo', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'chennai', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'chicago', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'delhi', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'essen', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'ho chi minh city', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'hong kong', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'istanbul', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'jakarta', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'johannesburg', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'karachi', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'khartoum', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'kinshasa', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'kolkata', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'lagos', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'lima', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'london', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'los angeles', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'madrid', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'manila', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'mexico city', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'miami', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'milan', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'moscow', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'mumbai', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'new york', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'osaka', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'paris', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'riyadh', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'san francisco', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'santiago', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'sao paulo', value: 'yellow', value_sort: 2, color: 'yellow', icon_class: 'city', key: 'player' },
    { name: 'seoul', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'shanghai', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'st. petersburg', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'sydney', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'taipei', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'tehran', value: 'black', value_sort: 3, color: 'black', icon_class: 'city', key: 'player' },
    { name: 'tokyo', value: 'red', value_sort: 4, color: 'red', icon_class: 'city', key: 'player' },
    { name: 'toronto', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' },
    { name: 'washington', value: 'blue', value_sort: 1, color: 'blue', icon_class: 'city', key: 'player' }
  ].freeze

  SPECIALS = [
    { name: 'airlift', value: 'special', value_sort: 5, color: 'light-orange', icon_class: 'helicopter', key: 'player' },
    { name: 'forecast', value: 'special', value_sort: 5, color: 'light-orange', icon_class: 'history', key: 'player' },
    { name: 'govt grant', value: 'special', value_sort: 5, color: 'light-orange', icon_class: 'dollar-sign', key: 'player' },
    { name: 'one quiet night', value: 'special', value_sort: 5, color: 'light-orange', icon_class: 'dove', key: 'player' },
    { name: 'resilient pop', value: 'special', value_sort: 5, color: 'light-orange', icon_class: 'user-nurse', key: 'player' }
  ]

  ROLES = [
    { name: 'dispatcher', color: 'magenta' },
    { name: 'medic', color: 'orange' },
    { name: 'ops expert', color: 'green' },
    { name: 'researcher', color: 'brown' },
    { name: 'scientist', color: 'white' }
  ]

  def add_game
    game = create_game(name: 'Pandemic', key: 'pandemic', min_players: 2, max_players: 4)

    (CITIES + SPECIALS).sort_by { |k| k[:name] }.each_with_index do |params, index|
      create_card(params.merge(game_id: game.id, name_sort: index))
    end

    CITIES.each_with_index do |params, index|
      create_card(params.merge(
        game_id: game.id,
        name_sort: index,
        value: 'infection',
        value_sort: 0,
        icon_class: 'disease',
        key: 'infection',
      ))
    end

    create_card(
      game_id: game.id,
      name: 'epidemic',
      name_sort: 0,
      value: 'epidemic',
      value_sort: 6,
      color: 'light-green',
      icon_class: 'disease',
      key: 'epidemic'
    )

    ROLES.each do |params|
      create_role(params.merge(game_id: game.id))
    end
  end
end
