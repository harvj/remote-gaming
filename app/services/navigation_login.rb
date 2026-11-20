module NavigationLogin
  RETURN_PATH = %r{\A(?:/|/modern_art|/staging/(?:directory|pandemic)|/replay|/admin/historical-users(?:/\d+)?|/s/[a-zA-Z0-9_-]+(?:/replay(?:\?frame=\d+)?)?)\z}

  def self.return_path(value)
    value if value.is_a?(String) && value.bytesize <= 512 && RETURN_PATH.match?(value)
  end

  def self.canonical_host
    ModernArtStaging.enabled? ? ModernArtStaging::GAME_HOST : ProductionReplay::HOST
  end

  def self.entry(host)
    return "/" unless ModernArtStaging.enabled?

    case host
    when ModernArtStaging::DIRECTORY_HOST then "/staging/directory"
    when ModernArtStaging::PANDEMIC_HOST then "/staging/pandemic"
    else "/modern_art"
    end
  end
end
