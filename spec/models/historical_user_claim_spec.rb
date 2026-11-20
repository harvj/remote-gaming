require "rails_helper"

RSpec.describe HistoricalUserClaim do
  it "distinguishes a prepared, issued, expired, and accepted invitation and validates the identity decision" do
    owner, user = create_list(:user, 2)
    claim = described_class.save_proposal!(user, owner: owner, email: "user@example.test", revision: "new").reload
    described_class.prepare!(user, owner: owner, revision: claim.lock_version.to_s)
    claim.reload
    issued_at = claim.confirmed_at + 1.second
    expires_at = issued_at + 1.day
    claim.update!(auth_invitation_reference: "auth-fixture", issued_at: issued_at, expires_at: expires_at)
    expect(claim.status(now: issued_at)).to eq(:issued)
    expect(claim.status(now: expires_at)).to eq(:expired)
    expect { described_class.save_proposal!(user, owner: owner, email: "change@example.test", revision: claim.lock_version.to_s) }
      .to raise_error(described_class::Unavailable)

    claim.update!(accepted_at: issued_at + 1.hour)
    expect(claim.status(now: expires_at)).to eq(:accepted)
    issue_identity = ->(profile, subject) do
      identity = AuthIdentity.create!(user: profile, issuer: "https://auth.harvj.com", subject: subject, evidence_reference: "fixture")
      AuthIdentityDecision.create!(auth_identity: identity, action: "linked", evidence_reference: "fixture")
    end
    claim.auth_identity_decision = issue_identity.call(owner, "incorrect")
    expect(claim).not_to be_valid
    claim.update!(auth_identity_decision: issue_identity.call(user, "correct"))
    expect(claim.reload.auth_identity_decision.auth_identity.user).to eq(user)
  end
end
