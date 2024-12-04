class AddDefaultValuesToCollections < ActiveRecord::Migration[7.0]
  def change
    change_column_default :collections, :bags, 0
    change_column_default :collections, :needs_bags, 0
    change_column_default :collections, :buckets, 0
    change_column_default :collections, :dropped_off_buckets, 0
  end
end
