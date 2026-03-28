class CreateFestivalWasteLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :festival_waste_logs do |t|
      t.references :festival_event, null: false, foreign_key: true
      t.references :festival_participant, null: true, foreign_key: true
      t.integer :day_number, null: false
      t.datetime :logged_at, null: false
      t.string :category, null: false
      t.decimal :weight_kg, precision: 8, scale: 3, null: false
      t.text :notes

      t.timestamps
    end
  end
end
