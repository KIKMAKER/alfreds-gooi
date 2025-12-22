class CreateQuotationItems < ActiveRecord::Migration[7.2]
  def change
    create_table :quotation_items do |t|
      t.references :quotation, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.float :quantity, default: 1.0
      t.float :amount  # Denormalized price from product at creation time

      t.timestamps
    end
  end
end
