require "rails_helper"
require "tempfile"

RSpec.describe ShellRegistry do
  def write_snapshot(path, entries, schema: 1)
    registry = { "schema_version" => schema, "specification_version" => "1.1.1", "applications" => entries }
    raw = JSON.generate(registry)
    Tempfile.create("registry-", File.dirname(path)) do |next_snapshot|
      next_snapshot.write(JSON.generate("format_version" => 1, "specification_version" => "1.1.1",
        "registry" => registry, "registry_json" => raw, "registry_sha256" => Digest::SHA256.hexdigest(raw)))
      next_snapshot.flush
      File.rename(next_snapshot.path, path)
    end
  end

  def entry(id, availability: "production")
    { "id" => id, "name" => id.capitalize, "canonical_url" => "https://#{id}.example.test/",
      "availability" => availability }
  end

  it "filters in registry order and reads an atomic replacement without restarting" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "registry.json")
      grants = %w[library second remote-gaming first withdrawn]
      expect(described_class.destinations(grants, path:)).to be_empty

      write_snapshot(path, [ entry("remote-gaming"), entry("first"), entry("second"),
        entry("library"), entry("withdrawn", availability: "withdrawn"), entry("ineligible") ])
      expect(described_class.destinations(grants, path:).pluck(:name)).to eq(%w[First Second Library])

      write_snapshot(path, [ entry("remote-gaming"), entry("second"), entry("first", availability: "withdrawn"), entry("library") ])
      expect(described_class.destinations(grants, path:).pluck(:name)).to eq(%w[Second Library])
      expect(described_class.destinations([], path:)).to be_empty

      write_snapshot(path, [ entry("first") ], schema: 2)
      expect(described_class.destinations(grants, path:)).to be_empty
      File.write(path, JSON.generate("format_version" => 1, "registry_json" => "{}"))
      expect(described_class.destinations(grants, path:)).to be_empty
    end
  end
end
