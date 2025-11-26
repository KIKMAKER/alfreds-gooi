class AddBucketsPerCollectionToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :buckets_per_collection, :integer
  end
end
