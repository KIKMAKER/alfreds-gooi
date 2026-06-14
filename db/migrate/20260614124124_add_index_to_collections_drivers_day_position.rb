class AddIndexToCollectionsDriversDayPosition < ActiveRecord::Migration[7.2]
  def change
    add_index :collections, %i[drivers_day_id position]
  end
end
