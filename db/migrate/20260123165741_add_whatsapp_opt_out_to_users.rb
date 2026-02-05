class AddWhatsappOptOutToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :whatsapp_opt_out, :boolean, default: false
  end
end
