class CreateInvoiceDiscountCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :invoice_discount_codes do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :discount_code, null: false, foreign_key: true
      t.decimal :discount_amount, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
