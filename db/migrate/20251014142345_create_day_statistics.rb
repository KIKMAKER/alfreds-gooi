class CreateDayStatistics < ActiveRecord::Migration[7.2]
  def change
    create_table :day_statistics do |t|
      t.references :drivers_day, null: false, foreign_key: true
      t.decimal :net_kg
      t.integer :bucket_count
      t.integer :full_count
      t.integer :half_count
      t.decimal :full_equiv
      t.decimal :avg_kg_bucket
      t.decimal :avg_kg_full
      t.integer :households
      t.integer :bags_sum
      t.decimal :route_hours
      t.decimal :stops_per_hr
      t.decimal :kg_per_hr
      t.integer :kms
      t.decimal :kg_per_km
      t.decimal :avoided_co2e_kg
      t.decimal :driving_co2e_kg
      t.decimal :net_co2e_kg
      t.decimal :trees_gross
      t.decimal :trees_to_offset_drive
      t.decimal :trees_net

      t.timestamps
    end
  end
end
