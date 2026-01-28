class AddForeignKeysToFinancialTables < ActiveRecord::Migration[7.2]
  def change
    # Add foreign keys for expense_imports
    add_foreign_key :expense_imports, :users

    # Add foreign keys for expenses
    add_foreign_key :expenses, :expense_imports
    add_foreign_key :expenses, :users, column: :verified_by_id

    # Add foreign keys for revenue_recognitions
    add_foreign_key :revenue_recognitions, :invoices
    add_foreign_key :revenue_recognitions, :subscriptions
  end
end
