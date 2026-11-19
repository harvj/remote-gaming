# Run against an isolated restored database after applying the release migrations.
GameSession.transaction do
  GameSession.connection.execute("SET TRANSACTION READ ONLY")
  initial_checkpoints = SessionFrame.checkpoints.where(sequence: 1, action: "session_created", format_version: 1)
  legacy_sessions = GameSession.ordinary.where.not(id: initial_checkpoints.select(:game_session_id))

  legacy_sessions.find_each do |table|
    member = table.players.first&.user
    abort "Legacy session #{table.id} has no readable member" unless member && table.can_view?(member)

    view = Representers::GameSession.call(table, viewer: member)
    abort "Legacy session #{table.id} did not render read-only" unless view.fetch(:readOnly) && view.fetch(:uri).present?
  end

  puts "#{legacy_sessions.count} legacy sessions rendered read-only for existing members"
end
