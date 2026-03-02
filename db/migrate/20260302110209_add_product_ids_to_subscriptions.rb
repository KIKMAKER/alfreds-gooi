class AddProductIdsToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :subscription_product_id, :integer
    add_column :subscriptions, :monthly_collection_product_id, :integer
    add_column :subscriptions, :volume_processing_product_id, :integer
  end
end
