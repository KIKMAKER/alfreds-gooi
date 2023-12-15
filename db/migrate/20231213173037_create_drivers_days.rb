class CreateDriversDays < ActiveRecord::Migration[7.0]
  def change
    create_table :drivers_days do |t|
      t.datetime :start_time
      t.datetime :end_time
      t.integer :start_kms
      t.integer :end_kms
      t.string :note
      t.references :user, null: false, foreign_key: true
      t.integer :total_buckets

      t.timestamps
    end
  end
end
