class CreateSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :subscriptions do |t|
      t.string :customer_id, null: :false
      t.string :access_code
      t.string :street_address
      t.string :suburb
      t.integer :duration
      t.datetime :start_date
      t.integer :collection_day
      t.integer :plan
      t.boolean :is_paused, null: false, default: false
      t.references :user, null: false, foreign_key: true
      t.datetime :holiday_start
      t.datetime :holiday_end

      t.timestamps
    end
  end
end
