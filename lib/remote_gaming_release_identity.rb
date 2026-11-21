require "json"
require "time"

class RemoteGamingReleaseIdentity
  NUMBER = /0|[1-9][0-9]*/
  VERSION = /(?:#{NUMBER})\.(?:#{NUMBER})\.(?:#{NUMBER})/
  SHA = /\A[0-9a-f]{40}\z/
  DIGEST = /\A[0-9a-f]{64}\z/
  CANDIDATE_FIELDS = %w[application artifact_sha256 candidate_number kind schema_version source_sha target_version].freeze
  RECEIPT_FIELDS = %w[acceptance_ref accepted_at candidate final_version kind publication_ref published_at schema_version verified_at].freeze

  def self.read(path)
    raw = File.binread(path, 16_385)
    JSON.parse(raw) if raw.bytesize <= 16_384
  rescue SystemCallError, JSON::ParserError
    nil
  end

  def self.candidate?(candidate, revision)
    candidate.is_a?(Hash) && candidate.keys.sort == CANDIDATE_FIELDS &&
      candidate.values_at("schema_version", "application", "kind", "source_sha") ==
        [ 1, "remote-gaming", "candidate", revision ] &&
      SHA.match?(revision) && candidate["artifact_sha256"].is_a?(String) && DIGEST.match?(candidate["artifact_sha256"]) &&
      candidate["target_version"].is_a?(String) && /\A#{VERSION}\z/.match?(candidate["target_version"]) &&
      candidate["candidate_number"].is_a?(Integer) && candidate["candidate_number"].positive?
  end

  def self.receipt?(receipt, candidate, now: Time.now)
    return false unless receipt.is_a?(Hash) && receipt.keys.sort == RECEIPT_FIELDS &&
      receipt.values_at("schema_version", "kind", "candidate", "final_version") ==
        [ 1, "publication", candidate, "v#{candidate.fetch("target_version")}" ]

    references = receipt.values_at("acceptance_ref", "publication_ref")
    return false unless references.all? { |value| value.is_a?(String) && !value.strip.empty? && value.length <= 512 }

    times = receipt.values_at("accepted_at", "published_at", "verified_at")
    return false unless times.all? { |time| time.is_a?(String) && /\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/.match?(time) }

    accepted, published, verified = times.map { |time| Time.iso8601(time) }
    accepted <= published && published <= verified && verified <= now
  rescue ArgumentError
    false
  end

  def self.receipt_name(candidate)
    "#{candidate.fetch("source_sha")}-#{candidate.fetch("artifact_sha256")}.json"
  end

  def initialize(root, receipts:, development_version:)
    release = root.realpath
    revision = release.basename.to_s
    @label = "v#{development_version}-dev"
    return unless release.parent.basename.to_s == "releases" && SHA.match?(revision)

    @label = "Version unavailable (#{revision})"
    stamped_revision, tag, extra = release.join(".release-version").read.split
    return unless stamped_revision == revision && extra.nil?

    if /\Av#{VERSION}\z/.match?(tag)
      @label = tag
      return
    end

    candidate = self.class.read(release.join(".release-candidate.json"))
    return unless self.class.candidate?(candidate, revision)

    @label = "v#{candidate.fetch("target_version")}-rc.#{candidate.fetch("candidate_number")}"
    return @label = "Version unavailable (#{revision})" unless @label == tag

    @candidate = candidate
    @receipt_path = receipts.join(self.class.receipt_name(candidate))
  rescue SystemCallError
    nil
  end

  def label
    return @label unless @candidate

    receipt = self.class.read(@receipt_path)
    @published ||= receipt.fetch("final_version") if self.class.receipt?(receipt, @candidate)
    @published || @label
  end
end
