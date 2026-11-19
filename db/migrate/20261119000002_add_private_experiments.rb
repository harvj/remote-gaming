class AddPrivateExperiments < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :experimental, :boolean, default: false, null: false
    add_reference :game_sessions, :experiment_owner, foreign_key: { to_table: :users }
    add_check_constraint :game_sessions, "experimental = (experiment_owner_id IS NOT NULL)", name: "game_sessions_experiment_owner"
    add_column :users, :dummy, :boolean, default: false, null: false
    add_column :session_frames, :actor_kind, :string

    create_table :dummy_accesses do |t|
      t.references :player, null: false, foreign_key: true, index: { unique: true }
      t.string :credential_digest
      t.string :browser_digest
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :dummy_accesses, :credential_digest, unique: true
  end
end
