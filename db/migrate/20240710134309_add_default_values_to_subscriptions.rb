class AddDefaultValuesToSubscriptions < ActiveRecord::Migration[7.0]
  change_column_default :subscriptions, :holiday_start, '2000-01-01'
  change_column_default :subscriptions, :holiday_end, '2000-01-01'
end
