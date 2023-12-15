class AddSoilForLIfeTimeToDriversDay < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers_days, :sfl_time, :datetime
  end
end
