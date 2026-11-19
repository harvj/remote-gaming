require "open3"
require "tmpdir"
require_relative "../../lib/remote_gaming_deployment"

RSpec.describe RemoteGamingDeployment do
  let(:sha) { "a" * 40 }

  before do
    allow(described_class).to receive(:command).with("git", "status", "--porcelain").and_return("")
    allow(described_class).to receive(:command).with("git", "symbolic-ref", "--short", "HEAD").and_return("main")
    allow(described_class).to receive(:command).with("git", "rev-parse", "HEAD").and_return(sha)
    allow(described_class).to receive(:command).with("git", "cat-file", "-t", sha).and_return("commit")
    allow(described_class).to receive(:command).with("git", "remote", "get-url", "origin")
      .and_return("git@github.com:harvj/remote-gaming.git")
    allow(described_class).to receive(:command).with("git", "ls-remote", "--exit-code", "origin", "refs/heads/main")
      .and_return("#{sha}\trefs/heads/main")
  end

  it "accepts only an explicit commit matching checked-out and published main" do
    expect(described_class.approved!(sha)).to eq(sha)
    expect { described_class.approved!("main") }.to raise_error(/full SHA/)
    expect { described_class.approved!("b" * 40) }.to raise_error(/Checked-out main/)
  end

  it "rejects an unpublished main even if the local tracking ref is stale" do
    allow(described_class).to receive(:command).with("git", "ls-remote", "--exit-code", "origin", "refs/heads/main")
      .and_return("#{'b' * 40}\trefs/heads/main")
    expect { described_class.approved!(sha) }.to raise_error(/live origin\/main/)
  end

  it "rejects deployment and rollback from a dirty checkout" do
    allow(described_class).to receive(:command).with("git", "status", "--porcelain").and_return("?? untracked")
    expect { described_class.approved!(sha) }.to raise_error(/clean checkout/)
    expect { described_class.approved!(sha, rollback: true) }.to raise_error(/clean checkout/)
  end

  it "selects the documented Capistrano paths without opening SSH" do
    {
      "production" => "/var/www/remote-gaming",
      "staging" => "/var/www/remote-gaming-staging"
    }.each do |environment, path|
      output, result = Open3.capture2e("bundle", "exec", "cap", environment, "deploy:config")
      expect(result).to be_success, output
      expect(output).to include("#{environment} remote-gaming #{path}")
      %w[deploy deploy:rollback].each do |task|
        output, result = Open3.capture2e({ "APPROVED_COMMIT" => nil }, "bundle", "exec", "cap", environment, task)
        expect(result).not_to be_success
        expect(output).to include("APPROVED_COMMIT")
      end
    end
  end

  def rollback_with_schema(current_schema, approved = "b" * 40, unfinished: false)
    Dir.mktmpdir do |base|
      current = "a" * 40
      prior = "b" * 40
      Dir.mkdir("#{base}/releases")
      Dir.mkdir("#{base}/releases/#{current}")
      Dir.mkdir("#{base}/releases/#{prior}")
      File.write("#{base}/.migration-in-progress", current) if unfinished
      File.write("#{base}/releases/#{current}/.remote-gaming-previous", "#{prior} #{'c' * 32}\n")
      body = <<~BASH
        source deploy/remote-gaming-deploy
        base=$1 previous_sha=$2 live=$3
        environment=staging unit=remote-gaming-staging.service
        current_revision() { echo "$previous_sha"; }
        schema_signature() { echo "$live"; }
        root_directory() { test -d "$1"; }
        check_database() { :; }
        switch_release() { echo "Switched to $1"; }
        systemctl() { echo "$*"; }
        health() { :; }
        rollback_release "$4"
      BASH
      Open3.capture2e("bash", "-c", body, "rollback-test", base, current, current_schema, approved)
    end
  end

  it "restores the exact prior application release only on a matching migration ledger" do
    output, status = rollback_with_schema("c" * 32)
    expect(status).to be_success, output
    expect(output).to include("Switched to #{'b' * 40}", "restart remote-gaming-staging.service")

    output, status = rollback_with_schema("d" * 32)
    expect(status).not_to be_success
    expect(output).to include("Schema changed")
    expect(output).not_to include("Switched", "restart")
  end

  it "rejects a rollback after a partial migration even when the ledger matches" do
    output, status = rollback_with_schema("c" * 32, unfinished: true)
    expect(status).not_to be_success
    expect(output).to include("migration attempt needs database review")
    expect(output).not_to include("Switched", "restart")
  end

  it "refuses an unrecorded rollback target before switching" do
    output, status = rollback_with_schema("c" * 32, "e" * 40)
    expect(status).not_to be_success
    expect(output).to include("immediately previous")
    expect(output).not_to include("Switched", "restart")
  end
end
