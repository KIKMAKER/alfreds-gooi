class ChangeDatetoDateInSubscriptions < ActiveRecord::Migration[7.0]
  def up
    change_column :subscriptions, :holiday_start, :date
    change_column :subscriptions, :holiday_end, :date
  end

  def down
    change_column :subscriptions, :holiday_start, :datetime
    change_column :subscriptions, :holiday_end, :datetime
  end
end
