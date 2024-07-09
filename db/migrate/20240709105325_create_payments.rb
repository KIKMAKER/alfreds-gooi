class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.integer :snapscan_id
      t.string :status
      t.integer :total_amount
      t.integer :tip_amount
      t.integer :fee_amount
      t.integer :settle_amount
      t.datetime :date
      t.string :user_reference
      t.string :merchant_reference
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
