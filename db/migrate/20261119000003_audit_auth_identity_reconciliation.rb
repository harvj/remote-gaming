class AuditAuthIdentityReconciliation < ActiveRecord::Migration[8.1]
  def change
    add_column :auth_identities, :revoked_at, :datetime

    create_table :auth_identity_decisions do |t|
      t.references :auth_identity, null: false, foreign_key: true
      t.string :action, null: false
      t.string :evidence_reference, null: false
      t.datetime :created_at, null: false
    end
  end
end
