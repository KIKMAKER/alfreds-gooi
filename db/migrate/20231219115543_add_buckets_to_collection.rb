class AddBucketsToCollection < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :buckets, :string
  end
end
