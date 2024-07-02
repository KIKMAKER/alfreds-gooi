class CreateInvoiceItems < ActiveRecord::Migration[7.0]
  def change
    create_table :invoice_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.float :quantity, default: 1, null: false
      t.float :amount

      t.timestamps
    end
  end
end
