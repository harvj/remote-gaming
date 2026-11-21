#!/usr/bin/env ruby
# Run through the existing privileged deployment operator after release publication.
require "fileutils"
require "net/http"
require "pathname"
require "tempfile"
require_relative "../lib/remote_gaming_release_identity"

REPOSITORY = "/repos/harvj/remote-gaming"
Identity = RemoteGamingReleaseIdentity

def github(path)
  uri = URI::HTTPS.build(host: "api.github.com", path: "#{REPOSITORY}/#{path}")
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 4) do |http|
    http.get(uri.request_uri, "Accept" => "application/vnd.github+json", "User-Agent" => "remote-gaming-release")
  end
  abort "GitHub publication lookup failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

stage, revision = ARGV
abort "Expected root operator, stage and full release revision" unless Process.euid.zero? &&
  %w[production staging].include?(stage) && revision && Identity::SHA.match?(revision)

suffix = stage == "staging" ? "-staging" : ""
state = Pathname("/var/lib/remote-gaming-shell-#{stage}")
release_root = Pathname("/var/www/remote-gaming#{suffix}/releases")
release = release_root.join(revision)
abort "Unknown release" unless release.realpath == release
candidate = Identity.read(release.join(".release-candidate.json"))
abort "Missing verified candidate identity" unless Identity.candidate?(candidate, revision)

filename = Identity.receipt_name(candidate)
acceptance_path = state.join("acceptance", filename)
stat = acceptance_path.lstat
abort "Acceptance must be an operator-owned, read-only record" unless stat.file? &&
  stat.uid.zero? && (stat.mode & 0o022).zero?
acceptance = Identity.read(acceptance_path)
abort "Acceptance must record the exact candidate and passing checks" unless acceptance.is_a?(Hash) &&
  acceptance["candidate"] == candidate && acceptance["status"] == "pass" &&
  acceptance["evidence_ref"].is_a?(String) && !acceptance["evidence_ref"].empty?

version = "v#{candidate.fetch("target_version")}"
ref = github("git/ref/tags/#{version}").fetch("object")
abort "Publication needs an annotated final tag" unless ref["type"] == "tag" && Identity::SHA.match?(ref.fetch("sha"))
target = github("git/tags/#{ref.fetch("sha")}").fetch("object")
abort "Publication tag refers to another commit" unless target.values_at("type", "sha") == [ "commit", revision ]

published = github("releases/tags/#{version}")
abort "Expected a published final release" unless published.values_at("tag_name", "draft", "prerelease") == [ version, false, false ]
asset = published.fetch("assets").find { |entry| entry["name"] == "remote-gaming-#{version}.tar.gz" }
abort "Published archive digest does not match the candidate" unless
  asset && asset["state"] == "uploaded" && asset["digest"] == "sha256:#{candidate.fetch("artifact_sha256")}"

receipt = {
  "schema_version" => 1, "kind" => "publication", "candidate" => candidate, "final_version" => version,
  "acceptance_ref" => acceptance.fetch("evidence_ref"),
  "accepted_at" => acceptance.fetch("accepted_at"),
  "publication_ref" => "#{published.fetch("html_url")} asset #{asset.fetch("id")}",
  "published_at" => published.fetch("published_at"), "verified_at" => Time.now.utc.iso8601
}
abort "Invalid acceptance or publication chronology" unless Identity.receipt?(receipt, candidate)

directory = state.join("publications")
FileUtils.mkdir_p(directory, mode: 0o755)
destination = directory.join(filename)
Tempfile.create([ "receipt-", ".json" ], directory) do |file|
  file.write(JSON.generate(receipt) + "\n")
  file.flush
  file.chmod(0o644)
  file.fsync
  begin
    File.link(file.path, destination)
    File.open(directory, &:fsync)
  rescue Errno::EEXIST
    existing = Identity.read(destination)
    abort "Conflicting publication receipt" unless Identity.receipt?(existing, candidate) &&
      receipt.except("verified_at") == existing.except("verified_at")
  end
end
puts "Verified #{version} publication for #{revision}"
