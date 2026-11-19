class ReconcileAuthIdentity
  class Conflict < StandardError; end

  def self.call(profile:, issuer:, subject:, evidence:, operation:)
    raise Conflict, "An issuer, verified subject, and evidence reference are required" if [ issuer, subject, evidence ].any?(&:blank?)
    raise Conflict, "The selected profile must belong to a real person" if profile.dummy?
    raise Conflict, "Expected link or revoke" unless %w[link revoke].include?(operation)

    profile.with_lock do
      identity = AuthIdentity.find_by(user: profile)
      if identity && [ identity.issuer, identity.subject ] != [ issuer, subject ]
        raise Conflict, "The profile already has a different identity decision"
      end

      if operation == "link"
        return identity if identity && identity.revoked_at.nil?

        identity ||= AuthIdentity.new(user: profile, issuer: issuer, subject: subject, evidence_reference: evidence)
        identity.update!(revoked_at: nil)
        AuthIdentityDecision.create!(auth_identity: identity, action: "linked", evidence_reference: evidence)
      else
        raise Conflict, "No identity decision exists to revoke" unless identity
        return identity if identity.revoked_at?

        identity.update!(revoked_at: Time.current)
        AuthLogin.where(auth_identity: identity).delete_all
        AuthIdentityDecision.create!(auth_identity: identity, action: "revoked", evidence_reference: evidence)
      end

      identity
    end
  end
end
