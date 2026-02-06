class AddContactIdToWhatsappMessages < ActiveRecord::Migration[7.2]
  def change
    add_reference :whatsapp_messages, :contact, null: true, foreign_key: true
  end
end
