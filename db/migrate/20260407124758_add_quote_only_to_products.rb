class AddQuoteOnlyToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :quote_only, :boolean, default: false, null: false
  end
end
