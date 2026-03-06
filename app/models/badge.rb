class Badge < ApplicationRecord
  belongs_to :game

  has_many :user_badges do
    def active
      find_by(active: true)
    end
  end
end
