class CreateContacts < ActiveRecord::Migration[7.2]
  def change
    create_table :contacts do |t|
      t.references :subscription, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name
      t.string :phone_number, null: false
      t.string :relationship # "owner", "spouse", "housemate", "family", "other"
      t.boolean :whatsapp_opt_out, default: false, null: false
      t.boolean :is_primary, default: false, null: false # The subscription owner

      t.timestamps
    end

    add_index :contacts, [:subscription_id, :phone_number], unique: true
    add_index :contacts, :phone_number
    add_index :contacts, [:subscription_id, :is_primary]
  end
end
