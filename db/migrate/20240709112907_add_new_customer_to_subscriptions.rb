class AddNewCustomerToSubscriptions < ActiveRecord::Migration[7.0]
  def change
    add_column :subscriptions, :is_new_customer, :boolean, default: true
  end
end
