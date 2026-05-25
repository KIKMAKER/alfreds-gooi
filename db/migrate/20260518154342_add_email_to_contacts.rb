class AddEmailToContacts < ActiveRecord::Migration[7.2]
  def change
    add_column :contacts, :email, :string
  end
end
