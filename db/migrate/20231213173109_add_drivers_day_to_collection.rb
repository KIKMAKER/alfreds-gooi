class AddDriversDayToCollection < ActiveRecord::Migration[7.0]
  def change
    add_reference :collections, :drivers_day, null: false, foreign_key: true
  end
end
