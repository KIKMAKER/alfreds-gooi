class AddCollectionDetailsToQuotations < ActiveRecord::Migration[7.1]
  def change
    add_column :quotations, :collections_per_week, :integer, default: 1, null: false
    add_column :quotations, :buckets_per_collection, :integer
  end
end
