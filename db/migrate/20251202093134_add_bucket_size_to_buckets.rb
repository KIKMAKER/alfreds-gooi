class AddBucketSizeToBuckets < ActiveRecord::Migration[7.2]
  def change
    add_column :buckets, :bucket_size, :integer, default: 25
  end
end
