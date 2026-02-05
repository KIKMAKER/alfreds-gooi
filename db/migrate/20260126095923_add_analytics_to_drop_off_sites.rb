class AddAnalyticsToDropOffSites < ActiveRecord::Migration[7.2]
  def change
    add_column :drop_off_sites, :average_duration_minutes, :float
    add_column :drop_off_sites, :total_duration_minutes, :integer, default: 0
    add_column :drop_off_sites, :completed_dropoffs_count, :integer, default: 0
  end
end
