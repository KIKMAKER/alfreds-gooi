class ChangeDriversDayIdToNullableInCollections < ActiveRecord::Migration[7.2]
  def change
    change_column_null :collections, :drivers_day_id, true
  end
end
