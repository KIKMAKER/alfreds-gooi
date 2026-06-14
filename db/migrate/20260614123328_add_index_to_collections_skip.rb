class AddIndexToCollectionsSkip < ActiveRecord::Migration[7.2]
  def change
    add_index :collections, :skip
  end
end
