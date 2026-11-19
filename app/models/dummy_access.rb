class DummyAccess < ApplicationRecord
  LIFETIME = 8.hours

  belongs_to :player
  delegate :session, :user, to: :player

  validate do
    errors.add(:player, "must be a dummy seat in an experiment") unless player&.user&.dummy? && player.session.experimental?
  end

  def issue!
    credential = SecureRandom.urlsafe_base64(32)
    update!(credential_digest: self.class.digest(credential), browser_digest: nil, expires_at: LIFETIME.from_now)
    credential
  end

  def revoke!
    update!(credential_digest: nil, browser_digest: nil, expires_at: Time.current)
  end

  def self.redeem!(credential)
    raise ActiveRecord::RecordNotFound unless credential.is_a?(String) && credential.match?(/\A[A-Za-z0-9_-]{43}\z/)

    digest = self.digest(credential)
    transaction do
      access = where("expires_at > ?", Time.current).lock.find_by!(credential_digest: digest)
      secret = SecureRandom.urlsafe_base64(32)
      access.update!(credential_digest: nil, browser_digest: self.digest(secret))
      [ access, { "id" => access.id, "secret" => secret } ]
    end
  end

  def self.authorized(ticket)
    return unless ticket.is_a?(Hash) && ticket["secret"].is_a?(String)

    where("expires_at > ?", Time.current).find_by(id: ticket["id"], browser_digest: digest(ticket["secret"]))
  end

  def self.digest(secret)
    Digest::SHA256.hexdigest(secret)
  end
end
