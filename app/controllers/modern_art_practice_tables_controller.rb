class ModernArtPracticeTablesController < ApplicationController
  before_action :require_owner
  before_action :load_table, only: %i[show update destroy]

  def index
    @tables = owned_tables.order(created_at: :desc)
  end

  def create
    table = ModernArtPracticeTable.open!(current_user, @game)
    redirect_to modern_art_practice_table_path(table.uid), status: :see_other
  end

  def show
    @board = @table.owner_view
    respond_to do |format|
      format.html
      format.json { render json: @board }
    end
  end

  def update
    @table.act!(params[:revision], params[:command], params[:value])
    ModernArtPracticeChannel.broadcast_to(@table, { changed: true })
    render json: @table.owner_view
  rescue ModernArtPracticeTable::StalePosition
    render json: { message: "The table advanced in another browser.", board: @table.reload.owner_view }, status: :conflict
  rescue Games::ModernArt::PracticeRules::IllegalCommand
    render json: { message: "That action is unavailable at this table.", board: @table.reload.owner_view }, status: :unprocessable_entity
  end

  def rules; end

  def destroy
    @table.with_lock { @table.destroy! }
    ModernArtPracticeChannel.broadcast_to(@table, { changed: true })
    redirect_to modern_art_practice_tables_path, status: :see_other
  end

  private

  def require_owner
    response.headers["Cache-Control"] = "private, no-store"
    head :not_found unless ModernArtPractice.owner?(request.host, current_user)
  end

  def owned_tables
    ModernArtPracticeTable.where(owner: current_user)
  end

  def load_table
    @table = owned_tables.find_by!(uid: params[:id])
  end
end
