class ChangeDataTypeFromStringToFloat < ActiveRecord::Migration[7.0]
  def change
    def up
      change_column :collections, :buckets, :integer, using: 'buckets::float'
    end

    def down
      # Change the data types back to the original types if you need to roll back
      change_column :collections, :buckets, :string
    end
  end
end
