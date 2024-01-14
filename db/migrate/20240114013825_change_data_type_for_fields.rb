class ChangeDataTypeForFields < ActiveRecord::Migration[7.0]
  def change
    def up
      change_column :subscriptions, :bags, :integer
      change_column :subscriptions, :buckets, :integer
    end

    def down
      # Change the data types back to the original types if you need to roll back
      change_column :subscriptions, :bags, :string
      change_column :subscriptions, :buckets, :string
    end
  end
end
