class RemoveWantsVeggiesFromCollections < ActiveRecord::Migration[7.2]
  def change
    remove_column :collections, :wants_veggies, :boolean
  end
end
