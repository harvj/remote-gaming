class AuthLogin < ApplicationRecord
  belongs_to :auth_identity

  validates :assurance, inclusion: { in: [ CanonicalAuth::PASSWORD, CanonicalAuth::MFA ] }

  def self.authorized(id)
    where("expires_at > ?", Time.current).joins(:auth_identity)
      .where(auth_identities: { issuer: ENV["REMOTE_GAMING_OIDC_ISSUER"] }).find_by(id: id)
  end
end
