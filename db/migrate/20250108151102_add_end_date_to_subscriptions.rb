class AddEndDateToSubscriptions < ActiveRecord::Migration[7.0]
  def change
    add_column :subscriptions, :end_date, :datetime
  end
end
