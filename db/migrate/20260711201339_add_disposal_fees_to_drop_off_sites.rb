class AddDisposalFeesToDropOffSites < ActiveRecord::Migration[7.2]
  def change
    add_column :drop_off_sites, :fee_per_kg, :decimal, precision: 8, scale: 2, default: 0, null: false
    add_column :drop_off_sites, :accepts_protein, :boolean, default: false, null: false
  end
end
