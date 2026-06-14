class AddIndexToCollectionsDate < ActiveRecord::Migration[7.2]
  def change
    add_index :collections, :date
  end
end
