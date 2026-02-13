class AddIsFinalDestinationToDropOffEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :drop_off_events, :is_final_destination, :boolean, default: false, null: false
  end
end
