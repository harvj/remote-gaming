class CreateAuthIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :auth_identities do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :issuer, null: false
      t.string :subject, null: false
      t.string :evidence_reference, null: false
      t.timestamps
    end
    add_index :auth_identities, %i[issuer subject], unique: true

    create_table :auth_logins do |t|
      t.references :auth_identity, null: false, foreign_key: { on_delete: :cascade }
      t.string :assurance, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
  end
end
