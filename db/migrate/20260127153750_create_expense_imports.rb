class CreateExpenseImports < ActiveRecord::Migration[7.2]
  def change
    create_table :expense_imports do |t|
      t.references :user, null: false
      t.string :filename, null: false
      t.string :bank_name
      t.date :statement_start_date
      t.date :statement_end_date
      t.integer :total_rows
      t.integer :imported_rows
      t.integer :skipped_rows
      t.text :import_notes

      t.timestamps
    end
  end
end
