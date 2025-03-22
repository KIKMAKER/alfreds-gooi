class AddDiscountCodeToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :discount_code, :string
  end
end
