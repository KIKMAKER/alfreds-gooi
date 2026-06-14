class AddIndexToDriversDaysDate < ActiveRecord::Migration[7.2]
  def change
    add_index :drivers_days, :date
  end
end
