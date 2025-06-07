class AddDiscountPercentToDiscountCodes < ActiveRecord::Migration[7.2]
  def change
    add_column :discount_codes, :discount_percent, :integer
  end
end
