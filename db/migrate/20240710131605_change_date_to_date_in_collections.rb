class ChangeDateToDateInCollections < ActiveRecord::Migration[7.0]
  def up
    change_column :collections, :date, :date
  end

  def down
    change_column :collections, :date, :datetime
  end
end
