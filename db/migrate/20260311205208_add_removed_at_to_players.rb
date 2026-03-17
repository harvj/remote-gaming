class AddRemovedAtToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :removed_at, :datetime
  end
end
