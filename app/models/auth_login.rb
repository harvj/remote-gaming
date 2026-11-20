class AuthLogin < ApplicationRecord
  belongs_to :auth_identity

  validates :assurance, inclusion: { in: [ CanonicalAuth::PASSWORD, CanonicalAuth::MFA ] }

  def self.authorized(id)
    return unless id

    identities = { issuer: ENV["REMOTE_GAMING_OIDC_ISSUER"], revoked_at: nil }
    if ModernArtStaging.enabled?
      subject = ModernArtStaging.owner_subject
      return if subject.blank?

      identities.merge!(subject: subject, user_id: ModernArtStaging::OWNER_PROFILE_ID)
    end
    login = where("expires_at > ?", Time.current).joins(:auth_identity).where(auth_identities: identities).find_by(id: id)
    login if login&.active_grant?
  end

  def self.end_session(id)
    return unless id

    login = find_by(id: id)
    return unless login

    login.destroy!
    CanonicalAuth.new.revoke(login.grant_token) if login.grant_ciphertext?
  rescue CanonicalAuth::InvalidLogin, ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def grant_token=(token)
    self.grant_ciphertext = grant_encryptor.encrypt_and_sign(token)
  end

  def grant_token
    grant_encryptor.decrypt_and_verify(grant_ciphertext) if grant_ciphertext?
  end

  def active_grant?
    return false unless grant_ciphertext?

    key = [ "oidc-access-verified", id, Digest::SHA256.hexdigest(grant_ciphertext) ]
    Rails.cache.fetch(key, expires_in: 20.seconds, skip_nil: true) do
      CanonicalAuth.new.active_access_token?(grant_token) || nil
    end
  rescue CanonicalAuth::InvalidLogin, ActiveSupport::MessageEncryptor::InvalidMessage
    false
  end

  private

  def grant_encryptor
    cipher = "aes-256-gcm"
    key = Rails.application.key_generator.generate_key("remote-gaming oidc access grants", ActiveSupport::MessageEncryptor.key_len(cipher))
    ActiveSupport::MessageEncryptor.new(key, cipher: cipher, serializer: :json)
  end
end
