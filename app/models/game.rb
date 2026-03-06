class Game < ApplicationRecord
  has_many :cards
  has_many :sessions, class_name: 'GameSession', dependent: :destroy
  has_many :roles
  has_many :badges

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true

  def play_class
    "Play::#{key.classify}".safe_constantize
  end
end
