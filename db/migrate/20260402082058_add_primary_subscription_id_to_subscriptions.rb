class AddPrimarySubscriptionIdToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    # A subscription with primary_subscription_id set is a "satellite" — it generates
    # collections on a different day but is never invoiced independently. All billing
    # flows through the primary subscription.
    add_column :subscriptions, :primary_subscription_id, :bigint
    add_index :subscriptions, :primary_subscription_id
  end
end
