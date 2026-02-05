class AddCurrentDropOffToDriversDays < ActiveRecord::Migration[7.2]
  def change
    add_reference :drivers_days, :current_drop_off_event, null: true, foreign_key: { to_table: :drop_off_events }
  end
end
