class AddCustomerNoteToCollections < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :customer_note, :string
  end
end
