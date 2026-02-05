class AddTimingToDropOffEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :drop_off_events, :arrival_time, :datetime
    add_column :drop_off_events, :departure_time, :datetime
    add_column :drop_off_events, :duration_minutes, :integer
    add_index :drop_off_events, :arrival_time
  end
end
