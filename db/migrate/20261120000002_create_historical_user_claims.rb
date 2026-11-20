class CreateHistoricalUserClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :historical_user_claims do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :proposed_by, null: false, foreign_key: { to_table: :users }
      t.string :proposed_email, null: false, limit: 254
      t.references :confirmed_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.string :auth_invitation_reference
      t.datetime :issued_at
      t.datetime :expires_at
      t.datetime :accepted_at
      t.references :auth_identity_decision, foreign_key: true, index: { unique: true }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :historical_user_claims, :auth_invitation_reference, unique: true
    add_check_constraint :historical_user_claims, <<~SQL.squish, name: "historical_claim_confirmation"
      (confirmed_at IS NULL) = (confirmed_by_id IS NULL)
    SQL
    add_check_constraint :historical_user_claims, <<~SQL.squish, name: "historical_claim_lifecycle"
      (issued_at IS NULL AND expires_at IS NULL AND auth_invitation_reference IS NULL AND accepted_at IS NULL)
      OR (issued_at IS NOT NULL AND expires_at IS NOT NULL AND auth_invitation_reference IS NOT NULL
          AND confirmed_at IS NOT NULL AND issued_at >= confirmed_at AND expires_at > issued_at
          AND (accepted_at IS NULL OR (accepted_at >= issued_at AND accepted_at < expires_at)))
    SQL
    add_check_constraint :historical_user_claims, "auth_identity_decision_id IS NULL OR accepted_at IS NOT NULL",
      name: "historical_claim_link_after_acceptance"
  end
end
