class AddDateToCollection < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :date, :datetime
  end
end
