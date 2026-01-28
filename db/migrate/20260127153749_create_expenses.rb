class CreateExpenses < ActiveRecord::Migration[7.2]
  def change
    create_table :expenses do |t|
      t.date :transaction_date, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :category, null: false
      t.string :description
      t.string :vendor
      t.string :payment_method
      t.string :reference_number
      t.text :notes

      # Accounting period
      t.integer :accounting_month, null: false
      t.integer :accounting_year, null: false

      # Import tracking
      t.references :expense_import, null: true
      t.boolean :verified, default: false
      t.references :verified_by, null: true

      t.timestamps
    end

    add_index :expenses, :transaction_date
    add_index :expenses, [:accounting_year, :accounting_month]
    add_index :expenses, :category
    add_index :expenses, :verified
  end
end
