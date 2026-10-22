class AddGrossAndContainerToFestivalWasteLogs < ActiveRecord::Migration[7.1]
  def change
    # weight_kg stays the NET figure everything else reads; these keep the
    # scale reading and container so a tare can be audited later.
    add_column :festival_waste_logs, :gross_kg, :decimal, precision: 8, scale: 3
    add_column :festival_waste_logs, :container_size, :integer
  end
end
