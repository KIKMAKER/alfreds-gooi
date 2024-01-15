class ChangeDataTypeFromStringToFloat < ActiveRecord::Migration[7.0]
  def up
    change_column :collections, :buckets, :float, using: 'buckets::float'
  end

  def down
    # Change the data types back to the original types if you need to roll back
    change_column :collections, :buckets, :string
  end
end
