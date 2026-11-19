class AuthIdentityDecision < ApplicationRecord
  belongs_to :auth_identity

  validates :action, inclusion: { in: %w[linked revoked] }
  validates :evidence_reference, presence: true

  def readonly?
    persisted? || super
  end
end
