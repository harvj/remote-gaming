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
