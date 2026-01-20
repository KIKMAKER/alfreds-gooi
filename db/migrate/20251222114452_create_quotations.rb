class CreateQuotations < ActiveRecord::Migration[7.2]
  def change
    create_table :quotations do |t|
      # Optional association to existing customer
      t.references :user, foreign_key: true, null: true
      t.references :subscription, foreign_key: true, null: true

      # Prospect contact details (for non-customers)
      t.string :prospect_name
      t.string :prospect_email
      t.string :prospect_phone
      t.string :prospect_company
      t.text :notes

      # Quotation details
      t.integer :number  # Auto-incrementing quote number
      t.date :created_date
      t.date :expires_at
      t.integer :status, default: 0  # enum: draft, sent, accepted, rejected, expired
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0

      t.timestamps
    end
  end
end
