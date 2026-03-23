class AddTitleToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :title, :string
  end
end
