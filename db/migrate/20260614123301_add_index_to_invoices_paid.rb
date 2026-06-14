class AddIndexToInvoicesPaid < ActiveRecord::Migration[7.2]
  def change
    add_index :invoices, :paid
  end
end
