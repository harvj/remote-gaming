class ShellRegistry
  MAX_BYTES = 2.megabytes
  APP_ID = "remote-gaming"

  def self.snapshot_path
    stage = ModernArtStaging.enabled? ? "staging" : "production"
    "/var/lib/remote-gaming-shell-#{stage}/registry.json"
  end

  def self.destinations(ids, path: snapshot_path)
    return [] if ids.empty?

    # The Infrastructure refresh process is the sole writer of this local snapshot.
    payload = File.binread(path, MAX_BYTES + 1)
    return [] if payload.bytesize > MAX_BYTES

    snapshot = JSON.parse(payload)
    return [] unless snapshot.is_a?(Hash) && snapshot["format_version"] == 1

    raw = snapshot["registry_json"]
    return [] unless raw.is_a?(String) && Digest::SHA256.hexdigest(raw) == snapshot["registry_sha256"]

    registry = JSON.parse(raw)
    return [] unless registry == snapshot["registry"] && registry.is_a?(Hash) &&
      registry["schema_version"] == 1 && registry["specification_version"] == snapshot["specification_version"]

    apps = registry["applications"]
    return [] unless apps.is_a?(Array) && apps.all? { |entry| valid_entry?(entry) }

    apps.filter_map do |entry|
      id = entry.fetch("id")
      if id != APP_ID && entry["availability"] == "production" && ids.include?(id)
        { name: entry.fetch("name"), url: entry.fetch("canonical_url") }
      end
    end
  rescue SystemCallError, JSON::ParserError
    []
  end

  def self.valid_entry?(entry)
    entry.is_a?(Hash) && entry["id"].is_a?(String) && entry["name"].is_a?(String) &&
      entry["name"].present? && entry["canonical_url"].is_a?(String) &&
      /\Ahttps:\/\/[a-z0-9.-]+\/\z/.match?(entry["canonical_url"]) &&
      %w[production withdrawn].include?(entry["availability"])
  end
  private_class_method :valid_entry?
end
