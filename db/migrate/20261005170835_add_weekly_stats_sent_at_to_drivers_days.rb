class AddWeeklyStatsSentAtToDriversDays < ActiveRecord::Migration[7.2]
  def change
    add_column :drivers_days, :weekly_stats_sent_at, :datetime
  end
end
