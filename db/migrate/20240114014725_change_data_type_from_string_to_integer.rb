class ChangeDataTypeFromStringToInteger < ActiveRecord::Migration[7.0]
  def up
    change_column :collections, :bags, :integer, using: 'bags::integer'
    change_column :collections, :buckets, :integer, using: 'buckets::integer'
  end

  def down
    # Change the data types back to the original types if you need to roll back
    change_column :collections, :bags, :string
    change_column :collections, :buckets, :string
  end
end
