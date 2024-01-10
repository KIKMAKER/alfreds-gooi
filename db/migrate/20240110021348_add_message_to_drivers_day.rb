class AddMessageToDriversDay < ActiveRecord::Migration[7.0]
  def change
    add_column :drivers_days, :message_from_alfred, :string
  end
end
