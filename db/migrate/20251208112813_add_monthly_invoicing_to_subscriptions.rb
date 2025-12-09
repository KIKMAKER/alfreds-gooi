class AddMonthlyInvoicingToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :monthly_invoicing, :boolean, default: false, null: false
    add_column :subscriptions, :contract_total, :decimal, precision: 10, scale: 2
    add_column :subscriptions, :next_invoice_date, :date
  end
end
