class AddSessionBranchLineage < ActiveRecord::Migration[8.1]
  def change
    add_reference :game_sessions, :parent_session, foreign_key: { to_table: :game_sessions }
    add_reference :game_sessions, :fork_frame, foreign_key: { to_table: :session_frames }
    add_column :game_sessions, :branch_rules_version, :integer
    add_check_constraint :game_sessions, <<~SQL.squish, name: "game_sessions_complete_branch_lineage"
      (parent_session_id IS NULL AND fork_frame_id IS NULL AND branch_rules_version IS NULL) OR
      (experimental AND parent_session_id IS NOT NULL AND parent_session_id <> id AND
       fork_frame_id IS NOT NULL AND branch_rules_version IS NOT NULL AND branch_rules_version > 0)
    SQL
  end
end
