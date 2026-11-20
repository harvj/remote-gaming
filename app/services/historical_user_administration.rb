module HistoricalUserAdministration
  # Profiles in the recovered production archive. IDs are stable across the
  # production and staging restores; sequence gaps and QA profiles are excluded.
  PROFILE_IDS = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17 ].freeze
  HOST = ProductionReplay::HOST
  OWNER_PROFILE_ID = 1

  def self.enabled?
    Rails.env.production? && !ModernArtStaging.enabled? && ENV["REMOTE_GAMING_HISTORICAL_ADMIN"] == "1"
  end

  def self.validate!
    ProductionReplay.validate_oidc!
    unless owner_subject.to_s.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/) && owner_evidence.present?
      raise "Historical user administration requires the attested production owner subject and evidence"
    end
  end

  def self.owner_subject
    ENV["REMOTE_GAMING_HISTORICAL_ADMIN_OWNER_SUBJECT"]
  end

  def self.owner_evidence
    ENV["REMOTE_GAMING_HISTORICAL_ADMIN_OWNER_EVIDENCE"]
  end

  def self.available_on?(host)
    enabled? && !ModernArtStaging.enabled? && host == HOST
  end

  def self.owner_identity?(identity)
    return false unless identity && owner_subject.present? && owner_evidence.present? && !identity.revoked_at? &&
      identity.issuer == "https://auth.harvj.com" && identity.subject == owner_subject

    user = identity.user
    return false unless user.id == OWNER_PROFILE_ID && user.username == "jim" && !user.dummy?

    decision = AuthIdentityDecision.where(auth_identity: identity).order(id: :desc).first
    decision&.action == "linked" && decision.evidence_reference == owner_evidence
  end

  def self.owner(browser_session, host)
    return unless available_on?(host) && !browser_session.key?(:dummy_browser)

    identity = AuthLogin.authorized(browser_session[:oidc_login])&.auth_identity
    identity.user if owner_identity?(identity)
  end

  def self.profiles
    User.where(id: PROFILE_IDS, dummy: false)
  end
end
