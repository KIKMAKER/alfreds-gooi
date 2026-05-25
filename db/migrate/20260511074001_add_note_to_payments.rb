class AddNoteToPayments < ActiveRecord::Migration[7.2]
  def change
    add_column :payments, :note, :text
  end
end
