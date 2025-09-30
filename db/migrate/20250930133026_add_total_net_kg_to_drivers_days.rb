class AddTotalNetKgToDriversDays < ActiveRecord::Migration[7.2]
  def change
    add_column :drivers_days, :total_net_kg, :float
  end
end
