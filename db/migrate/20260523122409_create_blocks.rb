class CreateBlocks < ActiveRecord::Migration[7.2]
  def change
    create_table :blocks do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :address
      t.text :description
      t.integer :resident_count
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
    add_index :blocks, :slug, unique: true
  end
end
