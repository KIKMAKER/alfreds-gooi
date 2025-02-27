class ChangeIsActiveToBooleanInProducts < ActiveRecord::Migration[7.0]
  def change
    remove_column :products, :is_active, :string
    add_column :products, :is_active, :boolean, default: false, null: false
  end
end
