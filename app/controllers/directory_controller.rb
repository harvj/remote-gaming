class DirectoryController < ActionController::Base
  layout "directory"

  def show
    directory = GameDirectory.new
    if GameDirectory::DIRECTORY_HOSTS.include?(request.host) ||
        (!Rails.env.production? && !request.host.end_with?(".#{GameDirectory::DOMAIN}"))
      @games = directory.games
      @title = "Remote Gaming"
    elsif (game = directory.internal_game(request.host))
      @games = [ game ]
      @title = game.fetch(:title)
      @game_page = true
    else
      head :not_found
    end
  end

  def ready
    Game.connection_pool.with_connection { |connection| connection.select_value("SELECT 1 FROM games LIMIT 1") }
    head :ok
  rescue ActiveRecord::ActiveRecordError, PG::Error => error
    Rails.logger.warn("Remote Gaming readiness failed (#{error.class})")
    head :service_unavailable
  end
end
