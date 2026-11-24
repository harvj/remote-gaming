class HistoricalExplorerController < ActionController::Base
  layout "directory"
  helper_method :directory_signed_in?
  before_action :public_response

  def index
    @title = "Modern Art historical games"
    @game_page = true
    @games = catalog.includes(players: :user).order(completed_at: :desc, id: :desc).map do |game|
      fields = approvals.fetch(game.uid)
      {
        uid: game.uid, date: game.completed_at.to_date,
        players: game.players.map.with_index(1) do |seat, number|
          { name: HistoricalExplorer.display_name(seat.user.name, number, fields),
            winner: seat.winner?, score: (seat.score if fields.include?("final_cash")) }
        end
      }
    end
  end

  def show
    table = catalog.find_by(uid: params[:uid])
    return head :not_found unless table

    @title = "Modern Art historical tabletop"
    @game_page = true
    @date = table.completed_at.to_date
    @uid = table.uid
    @board = Games::ModernArt::PublicHistoricalTable.call(table, approvals.fetch(@uid))
  end

  private

  def public_response
    response.headers["Cache-Control"] = "no-store"
    return head :not_found unless HistoricalExplorer.available_on?(request.host)
    head :not_acceptable unless request.format.html?
  end

  def catalog
    HistoricalExplorer.sessions(approvals)
  end

  def approvals
    @approvals ||= HistoricalExplorer.approvals
  end

  def directory_signed_in?
    return false unless CanonicalAuth.enabled? && !session.key?(:dummy_browser)

    BrowserIdentity.oidc_user(session).present?
  end
end
