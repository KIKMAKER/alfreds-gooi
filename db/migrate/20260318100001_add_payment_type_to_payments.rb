class AddPaymentTypeToPayments < ActiveRecord::Migration[7.1]
  def change
    add_column :payments, :payment_type, :string
    add_column :payments, :manual, :boolean, default: false, null: false
  end
end
