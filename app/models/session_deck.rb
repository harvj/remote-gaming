class SessionDeck < ApplicationRecord
  belongs_to :game_session
  has_many :cards, class_name: 'SessionCard', dependent: :destroy

  def deal_cards(players, count)
    count.times do
      players.each do |player|
        next_card.deal(player)
      end
    end
  end

  def next_card
    cards.undealt.shuffled.limit(1).first
  end
end
