class ChangeDateToDateInDriversDays < ActiveRecord::Migration[7.0]
  def up
    change_column :drivers_days, :date, :date
  end

  def down
    change_column :drivers_days, :date, :datetime
  end
end
