class Card < ApplicationRecord
  belongs_to :game

  validates :name, presence: true
  validates :value, presence: true
end
