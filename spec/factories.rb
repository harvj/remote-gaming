FactoryBot.define do
  factory :game do
    name { "Card Game" }
    key { 'card_game' }
    min_players { 1 }
    max_players { 3 }

    trait :cards do
      after(:create) do |game, evaluator|
        %w[one two three].each_with_index do |value, index|
          create(:card, :clubs, value: value, value_sort: index, game: game)
          create(:card, :hearts, value: value, value_sort: index, game: game)
          create(:card, :spades, value: value, value_sort: index, game: game)
          create(:card, :diamonds, value: value, value_sort: index, game: game)
        end
      end
    end
  end

  factory :user do
    username { 'prince' }
    name { 'Prince Rogers Nelson' }
    password { 'purple' }
  end

  factory :card do
    trait :clubs do
      name { 'clubs' }
      name_sort { 1 }
      color { 'black' }
      icon_class { 'wand' }
    end

    trait :hearts do
      name { 'hearts' }
      name_sort { 2 }
      color { 'red' }
      icon_class { 'cup' }
    end

    trait :spades do
      name { 'spades' }
      name_sort { 3 }
      color { 'black' }
      icon_class { 'sword' }
    end

    trait :diamonds do
      name { 'diamonds' }
      name_sort { 4 }
      color { 'red' }
      icon_class { 'coin' }
    end
  end
end
