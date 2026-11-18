class AddVersionedSessionFrames < ActiveRecord::Migration[8.1]
  def up
    change_table :session_frames, bulk: true do |table|
      table.bigint :sequence
      table.integer :format_version
      table.string :kind
      table.string :game_key
      table.jsonb :payload
      table.datetime :occurred_at
      table.bigint :context_frame_id
      table.bigint :corrects_frame_id
    end
    add_column :players, :table_captain, :boolean, default: false, null: false
    add_index :players, :game_session_id, unique: true, where: "table_captain", name: "index_players_on_session_captain"
    add_index :session_frames, [ :game_session_id, :sequence ], unique: true
    add_index :session_frames, :corrects_frame_id, unique: true
    add_index :session_frames, [ :game_key, :kind, :action ]
    execute <<~SQL
      CREATE FUNCTION reject_session_frame_change() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'session frames are append-only';
      END;
      $$;
      CREATE TRIGGER immutable_session_frames BEFORE UPDATE OR DELETE ON session_frames
        FOR EACH ROW EXECUTE FUNCTION reject_session_frame_change();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Versioned histories may contain irreplaceable data"
  end
end
