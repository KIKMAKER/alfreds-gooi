class CreateFillUps < ActiveRecord::Migration[7.0]
  def change
    create_table :fill_ups do |t|
      t.datetime :date
      t.decimal :volume
      t.integer :odometer
      t.decimal :cost
      t.decimal :cost_per_unit
      t.text :notes
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
