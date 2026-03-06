class User < ApplicationRecord
  devise :database_authenticatable, authentication_keys: [:username]

  has_many :players
  has_one :user_config

  has_many :sessions, -> do
    select("game_sessions.*, games.key, games.name").joins(:game)
  end, through: :players, class_name: 'GameSession'

  validates :username, uniqueness: true
  validates :name, uniqueness: true

  def config
    user_config
  end

  def to_param
    username
  end
end
