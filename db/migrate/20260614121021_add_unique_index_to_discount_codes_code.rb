class AddUniqueIndexToDiscountCodesCode < ActiveRecord::Migration[7.2]
  def change
    add_index :discount_codes, :code, unique: true
  end
end
