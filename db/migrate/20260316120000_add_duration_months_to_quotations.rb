class AddDurationMonthsToQuotations < ActiveRecord::Migration[7.1]
  def change
    add_column :quotations, :duration_months, :integer, default: 6, null: false
  end
end
