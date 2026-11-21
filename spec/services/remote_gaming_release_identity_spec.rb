require "rails_helper"
require Rails.root.join("lib/remote_gaming_release_identity")

RSpec.describe RemoteGamingReleaseIdentity do
  it "pins the boot artifact through pointer movement and promotes only its verified publication receipt" do
    Dir.mktmpdir do |directory|
      base = Pathname(directory)
      revision = "a" * 40
      predecessor = "c" * 40
      candidate = {
        "schema_version" => 1, "application" => "remote-gaming", "kind" => "candidate",
        "source_sha" => revision, "artifact_sha256" => "b" * 64, "target_version" => "0.4.3", "candidate_number" => 1
      }
      release = base.join("releases", revision)
      legacy = base.join("releases", predecessor)
      receipts = base.join("receipts")
      [ release, legacy, receipts ].each { |path| FileUtils.mkdir_p(path) }
      release.join(".release-version").write("#{revision} v0.4.3-rc.1")
      release.join(".release-candidate.json").write(JSON.generate(candidate))
      legacy.join(".release-version").write("#{predecessor} v0.4.2")
      current = base.join("current")
      current.make_symlink(release)
      boot = -> { described_class.new(current, receipts: receipts, development_version: "0.4.3") }
      running = boot.call
      expect(running.label).to eq("v0.4.3-rc.1")

      receipt = {
        "schema_version" => 1, "kind" => "publication", "candidate" => candidate,
        "final_version" => "v0.4.3", "acceptance_ref" => "acceptance/1", "publication_ref" => "publication/1",
        "accepted_at" => "2026-01-01T00:00:00Z", "published_at" => "2026-01-01T00:01:00Z",
        "verified_at" => "2026-01-01T00:02:00Z"
      }
      path = receipts.join(described_class.receipt_name(candidate))
      path.write(JSON.generate(receipt.merge("candidate" => candidate.merge("artifact_sha256" => "d" * 64))))
      expect(running.label).to eq("v0.4.3-rc.1")

      current.unlink
      current.make_symlink(legacy)
      expect(boot.call.label).to eq("v0.4.2")
      expect(running.label).to eq("v0.4.3-rc.1")

      path.write(JSON.generate(receipt))
      expect(running.label).to eq("v0.4.3")
      current.unlink
      current.make_symlink(release)
      expect(boot.call.label).to eq("v0.4.3")
      path.write("malformed")
      expect(running.label).to eq("v0.4.3")
    end
  end
end
