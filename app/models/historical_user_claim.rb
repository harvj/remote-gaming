class HistoricalUserClaim < ApplicationRecord
  class Unavailable < StandardError; end

  belongs_to :user
  belongs_to :proposed_by, class_name: "User"
  belongs_to :confirmed_by, class_name: "User", optional: true
  belongs_to :auth_identity_decision, optional: true

  normalizes :proposed_email, with: ->(email) { email.strip }
  validates :proposed_email, presence: true, length: { maximum: 254 }, format: URI::MailTo::EMAIL_REGEXP
  validate :link_provenance_matches_profile

  def self.save_proposal!(profile, owner:, email:, revision:)
    edit!(profile, revision) do |claim|
      claim.update!(proposed_email: email, proposed_by: owner, confirmed_at: nil, confirmed_by: nil)
    end
  end

  def self.prepare!(profile, owner:, revision:)
    edit!(profile, revision) do |claim|
      raise Unavailable unless claim.persisted? && claim.confirmed_at.nil?

      claim.update!(confirmed_at: Time.current, confirmed_by: owner)
    end
  end

  def self.edit!(profile, revision)
    profile.with_lock do
      # A revoked identity is still a prior claim and requires reconciliation.
      raise Unavailable if AuthIdentity.exists?(user: profile)

      claim = find_or_initialize_by(user: profile)
      current = claim.persisted? ? claim.lock_version.to_s : "new"
      raise Unavailable unless revision == current && claim.issued_at.nil?

      yield claim
      claim
    end
  end
  private_class_method :edit!

  def status(now: Time.current)
    return :accepted if accepted_at?
    return :expired if expires_at? && expires_at <= now
    return :issued if issued_at?
    return :prepared if confirmed_at?

    :proposed
  end

  private

  def link_provenance_matches_profile
    return unless auth_identity_decision

    unless accepted_at? && auth_identity_decision.action == "linked" && auth_identity_decision.auth_identity.user_id == user_id
      errors.add(:auth_identity_decision, "must record acceptance linked to the same historical profile")
    end
  end
end
