class AddWasteStreamToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :waste_stream, :integer, default: 0, null: false
    add_index  :subscriptions, :waste_stream
  end
end
