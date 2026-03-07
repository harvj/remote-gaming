namespace :db do
  desc "Add a game to the database"
  task build: :environment do
    game = ENV["GAME"]
    require_files(game)
    game_class = game.classify
    "GameBuild::#{game_class}".constantize.()
  end
end

def require_files(game)
  require File.join(Rails.root, "db", "build", "base")
  require File.join(Rails.root, "db", "build", "games", game)
end
