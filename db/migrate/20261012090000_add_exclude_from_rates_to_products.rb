class AddExcludeFromRatesToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :exclude_from_rates, :boolean, default: false, null: false
  end
end
