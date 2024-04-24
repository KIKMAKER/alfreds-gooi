class AddCarToFillUps < ActiveRecord::Migration[7.0]
  def change
    add_reference :fill_ups, :car, null: false, foreign_key: true
  end
end
