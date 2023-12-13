class AddCollectionOrderToSubscription < ActiveRecord::Migration[7.0]
  def change
    add_column :subscriptions, :collection_order, :integer
  end
end
