class CreateWhatsappMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :subscription, foreign_key: true
      t.string :message_type, null: false
      t.text :message_body, null: false
      t.string :twilio_sid
      t.string :status
      t.text :error_message
      t.date :collection_date
      t.boolean :used_template, default: false

      t.timestamps
    end

    add_index :whatsapp_messages, :message_type
    add_index :whatsapp_messages, :status
    add_index :whatsapp_messages, :collection_date
  end
end
