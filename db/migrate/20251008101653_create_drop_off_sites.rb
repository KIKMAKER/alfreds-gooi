class CreateDropOffSites < ActiveRecord::Migration[7.2]
  def change
    create_table :drop_off_sites do |t|
      t.string :name
      t.string :street_address
      t.string :suburb
      t.string :contact_name
      t.string :phone_number
      t.text :notes
      t.float :latitude
      t.float :longitude
      t.float :total_weight_kg, default: 0.0
      t.integer :total_dropoffs_count, default: 0
      t.integer :collection_day

      t.timestamps
    end
  end
end
