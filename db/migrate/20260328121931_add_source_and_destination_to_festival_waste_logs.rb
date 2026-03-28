class AddSourceAndDestinationToFestivalWasteLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :festival_waste_logs, :source, :integer
    add_column :festival_waste_logs, :destination, :integer
  end
end
