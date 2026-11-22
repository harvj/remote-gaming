class CreateModernArtPracticeTables < ActiveRecord::Migration[8.1]
  def change
    create_table :modern_art_practice_tables do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :uid, null: false, index: { unique: true }
      t.jsonb :setup, null: false
      t.jsonb :position, null: false
      t.jsonb :commands, null: false, default: []
      t.timestamps
    end
  end
end
