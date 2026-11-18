FactoryBot.define do
  factory :game do
    name { "Card Game" }
    key { 'card_game' }
    slug { 'cardgame' }
    min_players { 1 }
    max_players { 3 }

    trait :modern_art do
      name { "Modern Art" }
      key { "modern_art" }
      slug { "modernart" }
      min_players { 3 }
      max_players { 5 }

      after(:create) do |game|
        Play::ModernArt::DECKS.first.each_with_index do |(artist, auctions), artist_index|
          auctions.each_key.with_index do |auction, auction_index|
            game.cards.create!(name: artist, value: auction, name_sort: artist_index, value_sort: auction_index)
          end
        end
      end
    end

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
    sequence(:username) { |index| "player-#{index}" }
    sequence(:name) { |index| "Player #{index}" }
    password { 'purple' }

    trait :mariah do
      username { 'mariah' }
      name { 'Mariah Carey' }
    end

    trait :quincy do
      username { 'quincy' }
      name { 'Quincy Jones' }
    end
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
