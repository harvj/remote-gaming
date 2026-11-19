class AuthIdentity < ApplicationRecord
  belongs_to :user

  validate { errors.add(:user, "must be a real profile") if user&.dummy? }

  validates :issuer, :subject, :evidence_reference, presence: true
  validates :subject, uniqueness: { scope: :issuer }
  validates :user_id, uniqueness: true
end
