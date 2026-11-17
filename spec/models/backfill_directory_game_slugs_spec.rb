require "rails_helper"
require Rails.root.join("db/migrate/20260311205209_backfill_directory_game_slugs")

RSpec.describe BackfillDirectoryGameSlugs do
  it "only fills known missing slugs and preserves existing records and timestamps" do
    modern_art = Game.create!(key: "modern_art", name: "Modern Art")
    pandemic = Game.create!(key: "pandemic", name: "Pandemic", slug: "existing")
    other = Game.create!(key: "other", name: "Other")
    original = modern_art.attributes.except("slug")

    2.times { described_class.new.exec_migration(Game.connection, :up) }

    expect(modern_art.reload.slug).to eq("modernart")
    expect(modern_art.attributes.except("slug")).to eq(original)
    expect(pandemic.reload.slug).to eq("existing")
    expect(other.reload.slug).to be_nil
  end
end
