class AddReferredByCodeToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :referred_by_code, :string
  end
end
