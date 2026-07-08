class AllowNullSubscriptionOnRevenueRecognitions < ActiveRecord::Migration[7.1]
  def change
    # Order-linked invoices can exist without a subscription; their revenue
    # still has to be recognised. Recognition rows must also survive
    # subscription deletion (financial history is invoice-anchored).
    change_column_null :revenue_recognitions, :subscription_id, true
  end
end
