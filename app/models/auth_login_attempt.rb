class AuthLoginAttempt < ApplicationRecord
  def self.record!(attempt, browser:, destination:, historical_admin:)
    where(expires_at: ..Time.current).delete_all
    create!(state_digest: digest(attempt.fetch("state")), browser_digest: digest(browser),
      nonce: attempt.fetch("nonce"), verifier: attempt.fetch("verifier"),
      expires_at: Time.zone.at(attempt.fetch("expires")), destination: destination,
      historical_admin: historical_admin)
  end

  def self.consume(state:, browser:)
    return unless state.is_a?(String) && state.bytesize <= 128 && browser.is_a?(String)

    transaction do
      entry = where(state_digest: digest(state), browser_digest: digest(browser))
        .where("expires_at > ?", Time.current).lock.first
      entry&.delete
    end
  end

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
  private_class_method :digest

  def provider_attempt(state)
    { "state" => state, "nonce" => nonce, "verifier" => verifier, "expires" => expires_at.to_i }
  end
end
