class CreateContacts < ActiveRecord::Migration[7.0]
  def change
    create_table :contacts do |t|
      t.references :subscription, null: false, foreign_key: true
      t.string :name
      t.string :phone_number
      t.string :email
      t.boolean :is_available, default: true

      t.timestamps
    end
  end
end
