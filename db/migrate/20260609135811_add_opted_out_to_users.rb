class AddOptedOutToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :opted_out, :boolean, default: false, null: false
  end
end
