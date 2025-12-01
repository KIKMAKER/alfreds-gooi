class AddBucketSizeToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :bucket_size, :integer, default: 45
  end
end
