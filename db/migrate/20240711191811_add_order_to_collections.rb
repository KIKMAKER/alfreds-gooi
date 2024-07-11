class AddOrderToCollections < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :order, :integer, default: 0
  end
end
