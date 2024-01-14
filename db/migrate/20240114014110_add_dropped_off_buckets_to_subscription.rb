class AddDroppedOffBucketsToSubscription < ActiveRecord::Migration[7.0]
  def change
    add_column :subscriptions, :dropped_off_buckets, :integer
  end
end
