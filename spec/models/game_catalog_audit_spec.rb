require "rails_helper"

RSpec.describe GameCatalogAudit do
  before { described_class.call }

  it "accepts the canonical game definitions and flags an incomplete deck" do
    modern_art = create(:game, :modern_art)
    GameBuild::ModernArt::ROLES.each { |role| modern_art.roles.create!(role) }
    pandemic = Game.create!(name: "Pandemic", key: "pandemic", min_players: 2, max_players: 4)
    (GameBuild::Pandemic::CITIES + GameBuild::Pandemic::SPECIALS).each { |card| pandemic.cards.create!(card) }
    GameBuild::Pandemic::CITIES.each do |city|
      pandemic.cards.create!(city.merge(key: "infection", value: "infection"))
    end
    pandemic.cards.create!(key: "epidemic", name: "epidemic", value: "epidemic")
    GameBuild::Pandemic::ROLES.each { |role| pandemic.roles.create!(role) }

    expect(described_class.call).to be_empty
    modern_art.cards.first.destroy!
    expect(described_class.call).to include(/Modern Art card definitions/)
    pandemic.cards.where(key: "infection").first.update!(value: "invalid")
    expect(described_class.call).to include(/Pandemic card definitions/)
  end
end
