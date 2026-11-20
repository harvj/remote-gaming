class AddCanonicalLoginTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :auth_login_attempts do |t|
      t.string :state_digest, null: false, index: { unique: true }
      t.string :browser_digest, null: false
      t.string :nonce, null: false
      t.string :verifier, null: false
      t.string :destination, null: false
      t.boolean :historical_admin, null: false, default: false
      t.datetime :expires_at, null: false, index: true
    end
    add_column :auth_logins, :grant_ciphertext, :text
  end
end
