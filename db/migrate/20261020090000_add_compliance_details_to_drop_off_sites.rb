class AddComplianceDetailsToDropOffSites < ActiveRecord::Migration[7.1]
  def change
    # Filled in by the site manager; merged into the pre-filled facility letter.
    add_column :drop_off_sites, :legal_name, :string
    add_column :drop_off_sites, :signatory_name, :string
    add_column :drop_off_sites, :signatory_title, :string
    # Ceiling, not a schedule: most sites get one drop a week, many are twice.
    add_column :drop_off_sites, :max_deliveries_per_week, :integer
  end
end
