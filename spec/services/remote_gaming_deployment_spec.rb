require "rails_helper"
require Rails.root.join("lib/remote_gaming_deployment")

RSpec.describe RemoteGamingDeployment do
  let(:revision) { "a" * 40 }

  it "rejects an archive with a different digest or candidate identity" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("APPROVED_ARTIFACT_SHA256", "").and_return("b" * 64)
    allow(described_class).to receive(:command).with("tar", "-xOzf", "archive", ".release-version")
      .and_return("#{revision} v0.4.3-rc.1", "#{'c' * 40} v0.4.3-rc.1")
    expect { described_class.verify_artifact!("archive", revision, "c" * 64) }.to raise_error(/exact reviewed archive digest/)
    expect { described_class.verify_artifact!("archive", revision, "b" * 64) }.not_to raise_error
    expect { described_class.verify_artifact!("archive", revision, "b" * 64) }.to raise_error(/exact revision/)
  end

  it "requires a current signed check for the exact production revision" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("APPLICATION_SHELL_PREFLIGHT", "application-shell-preflight").and_return("preflight")
    allow(ENV).to receive(:fetch).with("APPLICATION_SHELL_REVIEW").and_return("review.json")
    allow(ENV).to receive(:fetch).with("APPLICATION_SHELL_STATE").and_return("state.json")
    expect(described_class).to receive(:system).with(
      "preflight", "--app", "remote-gaming", "--revision", revision, "--review", "review.json", "--state", "state.json"
    ).and_return(false)
    expect { described_class.verify_shell!(revision) }.to raise_error(/preflight failed/)
  end
end
