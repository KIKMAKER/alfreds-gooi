class AllowNullSubscriptionOnInvoices < ActiveRecord::Migration[7.0]
  def change
    change_column_null :invoices, :subscription_id, true
  end
end
