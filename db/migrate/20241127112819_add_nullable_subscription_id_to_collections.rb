class AddNullableSubscriptionIdToCollections < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :new_subscription_id, :bigint, null: true
  end
end
