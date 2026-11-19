require "uri"

module ModernArtStaging
  DIRECTORY_HOST = "staging.radioactivita.com"
  GAME_HOST = "modern-art.#{DIRECTORY_HOST}"
  PANDEMIC_HOST = "pandemic.#{DIRECTORY_HOST}"
  HOSTS = [ DIRECTORY_HOST, GAME_HOST, PANDEMIC_HOST ].freeze
  DATABASE = "remote_gaming_staging"
  GAME_KEY = "modern_art"
  ACCOUNTS = %w[staging_player_1 staging_player_2 staging_player_3].freeze

  def self.enabled?
    ENV["REMOTE_GAMING_PRIVATE_STAGING"] == "1"
  end

  def self.validate!
    uri = URI.parse(ENV.fetch("DATABASE_URL", ""))
    unless uri.scheme == "postgresql" && uri.host == "127.0.0.1" && uri.user == DATABASE &&
        uri.path == "/#{DATABASE}" && uri.password&.match?(/\A[0-9a-f]{64}\z/) && !uri.query && !uri.fragment
      raise "Private staging requires its dedicated loopback database and role"
    end
    unless ENV["SECRET_KEY_BASE"]&.match?(/\A[0-9a-f]{128}\z/) && !ENV.key?("SECRET_KEY_BASE_DUMMY")
      raise "Private staging requires its own session signing key"
    end
  rescue URI::InvalidURIError
    raise "Private staging requires a valid dedicated database URL", cause: nil
  end
end
