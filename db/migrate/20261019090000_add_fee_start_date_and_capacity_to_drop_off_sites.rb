class AddFeeStartDateAndCapacityToDropOffSites < ActiveRecord::Migration[7.1]
  def change
    # fee_start_date: disposal fees only accrue on drops from this date. NULL keeps
    # the old behaviour (every completed drop counts) for sites already charging.
    add_column :drop_off_sites, :fee_start_date, :date
    # Largest delivery the facility has confirmed in writing it can take, in kg.
    add_column :drop_off_sites, :max_kg_per_delivery, :decimal, precision: 8, scale: 2
  end
end
