class AddNewCustomerToCollections < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :new_customer, :boolean, default: false
  end
end
