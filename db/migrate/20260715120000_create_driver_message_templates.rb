class CreateDriverMessageTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :driver_message_templates do |t|
      # One row per client segment (standard, new_customer, once_off, commercial).
      # The driver's "Message a Day" tool picks the row matching each recipient.
      t.string :segment, null: false
      t.text   :body

      t.timestamps
    end

    add_index :driver_message_templates, :segment, unique: true
  end
end
