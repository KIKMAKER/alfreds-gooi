class AddSoilBagToCollections < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :soil_bag, :integer
  end
end
