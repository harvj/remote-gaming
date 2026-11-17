class BackfillDirectoryGameSlugs < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE games
      SET slug = CASE key WHEN 'modern_art' THEN 'modernart' WHEN 'pandemic' THEN 'pandemic' END
      WHERE slug IS NULL AND key IN ('modern_art', 'pandemic')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Game hostname assignments are preserved"
  end
end
