class AuthLogin < ApplicationRecord
  belongs_to :auth_identity

  validates :assurance, inclusion: { in: [ CanonicalAuth::PASSWORD, CanonicalAuth::MFA ] }

  def self.authorized(id)
    identities = { issuer: ENV["REMOTE_GAMING_OIDC_ISSUER"], revoked_at: nil }
    if ModernArtStaging.enabled?
      subject = ModernArtStaging.owner_subject
      return if subject.blank?

      identities.merge!(subject: subject, user_id: ModernArtStaging::OWNER_PROFILE_ID)
    end
    where("expires_at > ?", Time.current).joins(:auth_identity).where(auth_identities: identities).find_by(id: id)
  end
end
