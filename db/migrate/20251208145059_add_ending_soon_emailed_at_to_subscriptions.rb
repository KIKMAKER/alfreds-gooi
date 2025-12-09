class AddEndingSoonEmailedAtToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :ending_soon_emailed_at, :date
  end
end
