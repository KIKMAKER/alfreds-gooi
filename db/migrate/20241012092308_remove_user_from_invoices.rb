class RemoveUserFromInvoices < ActiveRecord::Migration[7.0]
  def change
    remove_column :invoices, :user_id, :bigint
  end
end
