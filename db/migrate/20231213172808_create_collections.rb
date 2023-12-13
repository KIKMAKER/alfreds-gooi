class CreateCollections < ActiveRecord::Migration[7.0]
  def change
    create_table :collections do |t|
      t.datetime :time
      t.string :kiki_note
      t.string :alfred_message
      t.string :bags
      t.references :subscription, null: false, foreign_key: true
      t.boolean :is_done, null: false, default: false
      t.boolean :skip, null: false, default: false
      t.integer :needs_bags

      t.timestamps
    end
  end
end
