class AddIndexToSubscriptionsCollectionDay < ActiveRecord::Migration[7.2]
  def change
    add_index :subscriptions, %i[status collection_day]
  end
end
