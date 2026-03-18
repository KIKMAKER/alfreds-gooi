class AddOrderToInvoices < ActiveRecord::Migration[7.1]
  def change
    add_reference :invoices, :order, null: true, foreign_key: true
  end
end
