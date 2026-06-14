class RenameEndingSoonEmailedAtOnSubscriptions < ActiveRecord::Migration[7.2]
  def change
    rename_column :subscriptions, :ending_soon_emailed_at, :ending_soon_emailed_on
  end
end
