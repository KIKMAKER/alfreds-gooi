class AddVeggiesToCollection < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :wants_veggies, :boolean
  end
end
