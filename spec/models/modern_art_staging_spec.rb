require "rails_helper"

RSpec.describe ModernArtStaging do
  let(:database_url) { "postgresql://remote_gaming_staging:#{'a' * 64}@127.0.0.1/remote_gaming_staging" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).with("DATABASE_URL", "").and_return(database_url)
    allow(ENV).to receive(:[]).with("SECRET_KEY_BASE").and_return("b" * 128)
  end

  it "accepts the dedicated database and a separate signing key" do
    expect { described_class.validate! }.not_to raise_error
  end

  context "with a production database target" do
    let(:database_url) { super().sub(%r{/remote_gaming_staging\z}, "/remote_gaming_production") }

    it "fails closed" do
      expect { described_class.validate! }.to raise_error(/dedicated loopback database/)
    end
  end

  context "with connection parameters that can override the target" do
    let(:database_url) { "#{super()}?dbname=remote_gaming_production" }

    it "rejects the override" do
      expect { described_class.validate! }.to raise_error(/dedicated loopback database/)
    end
  end
end
