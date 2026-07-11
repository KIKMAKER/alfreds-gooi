class AddWasteStreamToDropOffEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :drop_off_events, :waste_stream, :integer, default: 0, null: false
    add_index  :drop_off_events, :waste_stream
  end
end
