class AddDropOffEventToBuckets < ActiveRecord::Migration[7.2]
  def change
    add_reference :buckets, :drop_off_event, null: true, foreign_key: true
  end
end
