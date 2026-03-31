class AddMonthlyAmountsAndApprovalToSubscriptionsAndInvoices < ActiveRecord::Migration[7.2]
  def change
    # Store agreed monthly charge amounts on subscription at contract inception.
    # Prevents MonthlyInvoiceService from re-deriving amounts from product prices,
    # which breaks when products encode total contract cost rather than monthly rate.
    add_column :subscriptions, :monthly_volume_amount, :decimal, precision: 10, scale: 2
    add_column :subscriptions, :monthly_subscription_amount, :decimal, precision: 10, scale: 2

    # Admin approval gate for monthly invoices.
    # Monthly invoices are held (admin_approved: false) until admin reviews and approves.
    # Upfront invoices are created with admin_approved: true and email immediately.
    add_column :invoices, :admin_approved, :boolean, default: false, null: false
  end
end
