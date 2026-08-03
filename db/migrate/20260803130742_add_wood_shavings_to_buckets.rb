class AddWoodShavingsToBuckets < ActiveRecord::Migration[7.2]
  def change
    add_column :buckets, :wood_shavings, :boolean, default: false
  end
end
