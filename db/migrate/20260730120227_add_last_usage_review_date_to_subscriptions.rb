class AddLastUsageReviewDateToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :last_usage_review_date, :date
  end
end
