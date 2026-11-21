require "open3"
require "digest"

module RemoteGamingDeployment
  def self.helper(stage)
    stage.to_s == "staging" ? "/usr/local/sbin/remote-gaming-staging-deploy" : "/usr/local/sbin/remote-gaming-deploy"
  end

  REPOSITORIES = %w[git@github.com:harvj/remote-gaming.git https://github.com/harvj/remote-gaming.git].freeze
  SHA = /\A[0-9a-f]{40}\z/

  def self.command(*args)
    output, _, status = Open3.capture3(
      { "GIT_TERMINAL_PROMPT" => "0", "GIT_SSH_COMMAND" => "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes" }, *args
    )
    raise "Deployment preflight failed: #{args.first} #{args[1]}" unless status.success?

    output.strip
  end

  def self.verify_artifact!(archive, revision, checksum)
    expected = ENV.fetch("APPROVED_ARTIFACT_SHA256", "")
    unless /\A[0-9a-f]{64}\z/.match?(expected) && checksum == expected
      raise "Set APPROVED_ARTIFACT_SHA256 to the exact reviewed archive digest"
    end

    stamp = command("tar", "-xOzf", archive, ".release-version")
    unless /\A#{revision} v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)-rc\.[1-9][0-9]*\z/.match?(stamp)
      raise "Deployment requires an annotated release-candidate tag on the exact revision"
    end
  end

  def self.verify_shell!(revision)
    executable = ENV.fetch("APPLICATION_SHELL_PREFLIGHT", "application-shell-preflight")
    review = ENV.fetch("APPLICATION_SHELL_REVIEW") { raise "Set APPLICATION_SHELL_REVIEW to the exact candidate review" }
    state = ENV.fetch("APPLICATION_SHELL_STATE") { raise "Set APPLICATION_SHELL_STATE to the durable publication checkpoint" }
    unless system(executable, "--app", "remote-gaming", "--revision", revision, "--review", review, "--state", state)
      raise "Application Shell preflight failed. Resolve the reported checks before retrying."
    end
  end

  def self.approved!(revision, rollback: false)
    raise "Set APPROVED_COMMIT to the reviewed full SHA" unless SHA.match?(revision.to_s)
    raise "Deployment requires a clean checkout" unless command("git", "status", "--porcelain").empty?
    return revision if rollback

    unless command("git", "symbolic-ref", "--short", "HEAD") == "main" &&
        command("git", "rev-parse", "HEAD") == revision && command("git", "cat-file", "-t", revision) == "commit"
      raise "Checked-out main must be the approved commit"
    end
    unless REPOSITORIES.include?(command("git", "remote", "get-url", "origin"))
      raise "Unexpected origin repository"
    end
    live = command("git", "ls-remote", "--exit-code", "origin", "refs/heads/main")
    raise "Approved commit must equal live origin/main" unless live.split == [ revision, "refs/heads/main" ]

    revision
  end
end
