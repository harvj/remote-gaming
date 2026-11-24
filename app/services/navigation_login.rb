module NavigationLogin
  RETURN_PATH = %r{\A(?:/|/modern_art|/replay|/admin/historical-users(?:/\d+)?|/s/[a-zA-Z0-9_-]+(?:/replay(?:\?frame=\d+)?)?)\z}

  def self.return_path(value)
    return unless value.is_a?(String) && value.bytesize <= 512
    return "/" if ModernArtStaging.enabled? && %w[/modern_art /staging/directory /staging/pandemic].include?(value)

    value if RETURN_PATH.match?(value)
  end

  def self.canonical_host
    ModernArtStaging.enabled? ? ModernArtStaging::GAME_HOST : ProductionReplay::HOST
  end

  def self.directory_home(host)
    return "https://#{ModernArtStaging::DIRECTORY_HOST}/" if ModernArtStaging.enabled? && ModernArtStaging::HOSTS.include?(host)

    case host
    when "gaming.harvj.com" then "https://gaming.harvj.com/"
    when "radioactivita.com", HistoricalExplorer::HOST, "modernart.radioactivita.com", "pandemic.radioactivita.com" then "https://radioactivita.com/"
    else "/"
    end
  end

  def self.entry(_host)
    HistoricalUserAdministration.enabled? ? "/admin/historical-users" : "/"
  end
end
