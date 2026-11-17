require "uri"
require "yaml"

class GameDirectory
  DOMAIN = "radioactivita.com"
  DIRECTORY_HOSTS = [ DOMAIN, "gaming.harvj.com" ].freeze
  LABEL = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

  def initialize(path = ENV.fetch("GAME_DIRECTORY_PATH", Rails.root.join("config/game_directory.yml")))
    @games = YAML.safe_load_file(path).map do |slug, entry|
      raise ArgumentError, "Invalid game hostname label" unless slug.is_a?(String) && LABEL.match?(slug)

      title = entry.fetch("title")
      description = entry.fetch("description")
      available = entry.fetch("available")
      destination = entry.fetch("destination", "https://#{slug}.#{DOMAIN}/")
      uri = URI.parse(destination)
      if ![ true, false ].include?(available) || [ title, description ].any? { |value| !value.is_a?(String) || value.blank? } ||
          !uri.is_a?(URI::HTTPS) || uri.host.blank? || uri.userinfo
        raise ArgumentError, "Invalid directory entry for #{slug}"
      end

      if slug == "arkham" && uri.host != "arkham.#{DOMAIN}"
        raise ArgumentError, "Arkham must use its independent hostname"
      end

      { slug: slug, title: title, description: description, available: available, destination: destination }
    end.sort_by { |entry| entry.fetch(:title) }
  end

  attr_reader :games

  def internal_game(host)
    games.find do |game|
      game.fetch(:slug) != "arkham" &&
        host == "#{game.fetch(:slug)}.#{DOMAIN}" &&
        URI.parse(game.fetch(:destination)).host == host
    end
  end
end
