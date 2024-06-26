class AddCustiomerIDtoUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :customer_id, :string
  end
end
