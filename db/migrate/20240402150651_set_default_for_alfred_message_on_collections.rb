class SetDefaultForAlfredMessageOnCollections < ActiveRecord::Migration[7.0]
  def change
    change_column_default :collections, :alfred_message, from: nil, to: "N/A"
  end
end
