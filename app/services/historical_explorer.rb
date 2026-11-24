module HistoricalExplorer
  HOST = "modern-art.radioactivita.com"
  FIELDS = %w[names badges final_cash hands history].freeze
  UID = /\A[a-z0-9][a-z0-9-]{0,79}\z/

  def self.enabled?
    ENV["REMOTE_GAMING_HISTORICAL_EXPLORER"] == "1"
  end

  def self.host
    ModernArtStaging.enabled? ? ModernArtStaging::GAME_HOST : HOST
  end

  def self.available_on?(host)
    enabled? && host == self.host
  end

  def self.approvals
    entries = JSON.parse(ENV.fetch("REMOTE_GAMING_PUBLIC_HISTORICAL_SESSIONS", "{}"))
    return {} unless entries.is_a?(Hash) && entries.all? do |uid, fields|
      UID.match?(uid) && fields.is_a?(Array) && (fields - FIELDS).empty?
    end

    entries
  rescue JSON::ParserError
    {}
  end

  def self.sessions(approved)
    dummy_sessions = Player.joins(:user).where(users: { dummy: true }).select(:game_session_id)
    digital_sessions = ModernArtPracticeTable.where("setup ->> 'mode' = 'human'").select(:uid)
    GameSession.ordinary.joins(:game).where(uid: approved.keys, games: { key: "modern_art" },
      state: "completed", parent_session_id: nil, experiment_owner_id: nil, fork_frame_id: nil)
      .where.not(completed_at: nil).where.not(id: dummy_sessions).where.not(uid: digital_sessions)
  end

  def self.display_name(name, number, fields)
    fields.include?("names") && name.present? ? name : "Player #{number}"
  end
end
