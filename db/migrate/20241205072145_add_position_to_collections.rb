class AddPositionToCollections < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :position, :integer
  end
end
