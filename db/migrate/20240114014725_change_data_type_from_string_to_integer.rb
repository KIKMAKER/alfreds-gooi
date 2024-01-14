class ChangeDataTypeFromStringToInteger < ActiveRecord::Migration[7.0]
  def up
    change_column :collections, :bags, :integer, using: 'bags::integer'
  end

  def down
    # Change the data types back to the original types if you need to roll back
    change_column :collections, :bags, :string
  end
end
