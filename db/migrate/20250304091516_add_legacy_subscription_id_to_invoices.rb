class AddLegacySubscriptionIdToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :legacy_subscription_id, :integer
  end
end
