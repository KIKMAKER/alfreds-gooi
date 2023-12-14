class AddDateToDriversDay < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers_days, :date, :datetime
  end
end
