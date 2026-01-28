class CreateRevenueRecognitions < ActiveRecord::Migration[7.2]
  def change
    create_table :revenue_recognitions do |t|
      t.references :invoice, null: false
      t.references :subscription, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :period_month, null: false
      t.integer :period_year, null: false
      t.decimal :recognized_amount, precision: 10, scale: 2, null: false
      t.string :recognition_type

      t.timestamps
    end

    add_index :revenue_recognitions, [:period_year, :period_month]
  end
end
