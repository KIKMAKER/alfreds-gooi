class CreateBuckets < ActiveRecord::Migration[7.2]
  def change
    create_table :buckets do |t|
      t.references :drivers_day, null: false, foreign_key: true
      t.float :weight_kg, default: 0
      t.boolean :half, default: false

      t.timestamps
    end
  end
end
