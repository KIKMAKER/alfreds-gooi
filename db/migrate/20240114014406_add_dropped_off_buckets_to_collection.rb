class AddDroppedOffBucketsToCollection < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :dropped_off_buckets, :integer
  end
end
