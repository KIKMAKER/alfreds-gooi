class CreateFillUps < ActiveRecord::Migration[7.0]
  def change
    create_table :fill_ups do |t|
      t.datetime :date, default: DateTime.now
      t.decimal :volume
      t.integer :odometer
      t.decimal :cost, precision: 10, scale: 2
      t.decimal :cost_per_unit, precision: 10, scale: 2
      t.text :notes
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
