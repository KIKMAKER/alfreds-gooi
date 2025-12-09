class AddCollectionsPerWeekToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :collections_per_week, :integer, default: 1, null: false
  end
end
