class AddOgToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :og, :boolean, default: false
  end
end
