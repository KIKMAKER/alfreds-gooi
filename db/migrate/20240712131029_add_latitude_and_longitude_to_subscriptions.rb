class AddLatitudeAndLongitudeToSubscriptions < ActiveRecord::Migration[7.0]
  def change
    add_column :subscriptions, :latitude, :float
    add_column :subscriptions, :longitude, :float
  end
end
