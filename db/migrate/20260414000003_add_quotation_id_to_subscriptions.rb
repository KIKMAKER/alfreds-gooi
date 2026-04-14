class AddQuotationIdToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_reference :subscriptions, :quotation, foreign_key: true, null: true
  end
end
