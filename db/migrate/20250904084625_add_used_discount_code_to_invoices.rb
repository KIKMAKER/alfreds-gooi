class AddUsedDiscountCodeToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :used_discount_code, :boolean
  end
end
