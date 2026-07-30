class AddWasteStreamOverrideToCollections < ActiveRecord::Migration[7.2]
  def change
    add_column :collections, :waste_stream_override, :integer
  end
end
