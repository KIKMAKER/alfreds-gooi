class CreateInterests < ActiveRecord::Migration[7.2]
  def change
    create_table :interests do |t|
      t.string :name
      t.string :email
      t.string :suburb
      t.text :note

      t.timestamps
    end
  end
end
