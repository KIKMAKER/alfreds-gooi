class CreateDropOffEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :drop_off_events do |t|
      t.references :drop_off_site, null: false, foreign_key: true
      t.references :drivers_day, null: false, foreign_key: true
      t.date :date
      t.datetime :time
      t.boolean :is_done, default: false, null: false
      t.integer :buckets_dropped, default: 0
      t.float :weight_kg, default: 0.0
      t.string :driver_note
      t.integer :position

      t.timestamps
    end
  end
end
