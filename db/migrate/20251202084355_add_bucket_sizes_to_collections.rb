class AddBucketSizesToCollections < ActiveRecord::Migration[7.2]
  def change
    add_column :collections, :buckets_45l, :integer, default: 0
    add_column :collections, :buckets_25l, :integer, default: 0
  end
end
