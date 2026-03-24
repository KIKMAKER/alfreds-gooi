class AddPaymentReminderSentAtToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :payment_reminder_sent_at, :date
  end
end
