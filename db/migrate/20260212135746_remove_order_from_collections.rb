class RemoveOrderFromCollections < ActiveRecord::Migration[7.2]
  def change
    remove_column :collections, :order, :integer
  end
end
