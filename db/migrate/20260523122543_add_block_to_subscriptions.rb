class AddBlockToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_reference :subscriptions, :block, null: true, foreign_key: true
  end
end
