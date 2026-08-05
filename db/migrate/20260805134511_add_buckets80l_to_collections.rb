class AddBuckets80lToCollections < ActiveRecord::Migration[7.2]
  def change
    add_column :collections, :buckets_80l, :integer, default: 0
  end
end
