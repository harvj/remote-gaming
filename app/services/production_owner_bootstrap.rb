module ProductionOwnerBootstrap
  EVIDENCE_FORMAT = /\ARG-P15-PROD-AUTH-OWNER-\d+-\d+\z/

  def self.enabled?
    Rails.env.production? && !ModernArtStaging.enabled? && ENV["REMOTE_GAMING_PRODUCTION_OWNER_BOOTSTRAP"] == "1"
  end

  def self.validate!
    HistoricalUserAdministration.validate!
    if ProductionReplay.enabled? || HistoricalUserAdministration.enabled? ||
        !EVIDENCE_FORMAT.match?(HistoricalUserAdministration.owner_evidence.to_s)
      raise "Production owner reconciliation requires production evidence with replay and administration disabled"
    end
  end

  # Called only after CanonicalAuth verifies the exact client's signed token and grant.
  def self.link!(issuer:, subject:)
    validate!
    unless enabled? && issuer == "https://auth.harvj.com" && subject == HistoricalUserAdministration.owner_subject
      raise CanonicalAuth::InvalidLogin
    end

    profile = User.find(HistoricalUserAdministration::OWNER_PROFILE_ID)
    profile.with_lock do
      unless profile.username == "jim" && !profile.dummy? && profile.players.count == 83
        raise CanonicalAuth::InvalidLogin
      end

      identity = AuthIdentity.find_by(user: profile)
      if identity
        raise CanonicalAuth::InvalidLogin unless HistoricalUserAdministration.owner_identity?(identity)

        return identity
      end

      ReconcileAuthIdentity.call(profile: profile, issuer: issuer, subject: subject,
        evidence: HistoricalUserAdministration.owner_evidence, operation: "link")
    end
  end
end
