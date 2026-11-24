class DirectoryController < ActionController::Base
  layout "directory"
  helper_method :directory_signed_in?
  before_action :keep_signed_in_navigation_private, only: %i[show staging]

  def show
    directory = GameDirectory.new
    if GameDirectory::DIRECTORY_HOSTS.include?(request.host) ||
        (!Rails.env.production? && !request.host.end_with?(".#{GameDirectory::DOMAIN}"))
      @games = directory.games.map do |game|
        if game.fetch(:slug) == "modernart" && HistoricalExplorer.available_on?(HistoricalExplorer::HOST)
          game.merge(available: true, destination: "https://#{HistoricalExplorer::HOST}/",
            description: "Explore completed Modern Art games, paintings, and recorded results.")
        else
          game
        end
      end
      @title = "Remote Gaming"
    elsif (game = directory.internal_game(request.host))
      @games = [ game ]
      @title = game.fetch(:title)
      @game_page = true
    else
      head :not_found
    end
  end

  def staging
    response.headers["Cache-Control"] = "no-store"
    render_staging(pandemic: request.path_parameters[:staging_page] == "pandemic")
  end

  def staging_content
    destination = if request.path_parameters[:staging_page] == "pandemic"
      "https://#{ModernArtStaging::PANDEMIC_HOST}/"
    else
      "https://#{ModernArtStaging::DIRECTORY_HOST}/directory"
    end
    redirect_to destination, allow_other_host: true
  end

  def ready
    Game.connection_pool.with_connection { |connection| connection.select_value("SELECT 1 FROM games LIMIT 1") }
    head :ok
  rescue ActiveRecord::ActiveRecordError, PG::Error => error
    Rails.logger.warn("Remote Gaming readiness failed (#{error.class})")
    head :service_unavailable
  end

  private

  def render_staging(pandemic:)
    directory = GameDirectory.new
    @directory_url = NavigationLogin.directory_home(request.host)
    @game_page = pandemic
    @title = @game_page ? "Pandemic" : "Remote Gaming staging"
    @games = directory.games.filter_map do |game|
      case game.fetch(:slug)
      when "modernart"
        game.merge(available: true, destination: "https://#{ModernArtStaging::GAME_HOST}/") unless @game_page
      when "pandemic"
        game.merge(available: false, destination: "https://#{ModernArtStaging::PANDEMIC_HOST}/")
      end
    end
    render :show
  end

  def directory_signed_in?
    return @directory_signed_in if defined?(@directory_signed_in)

    user = if CanonicalAuth.enabled?
      BrowserIdentity.oidc_user(session) unless session.key?(:dummy_browser)
    else
      request.env["warden"]&.user(:user)
    end
    @directory_signed_in = user.present? && !user.dummy?
  end

  def keep_signed_in_navigation_private
    response.headers["Cache-Control"] = "no-store" if directory_signed_in?
  end
end
