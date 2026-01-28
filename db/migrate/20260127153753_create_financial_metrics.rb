class CreateFinancialMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :financial_metrics do |t|
      t.integer :year, null: false
      t.integer :month, null: false

      # Revenue (both views)
      t.decimal :cash_revenue, precision: 10, scale: 2, default: 0
      t.decimal :recognized_revenue, precision: 10, scale: 2, default: 0

      # Expenses by category
      t.decimal :cogs_total, precision: 10, scale: 2, default: 0
      t.decimal :operational_total, precision: 10, scale: 2, default: 0
      t.decimal :fixed_total, precision: 10, scale: 2, default: 0
      t.decimal :marketing_total, precision: 10, scale: 2, default: 0
      t.decimal :admin_total, precision: 10, scale: 2, default: 0
      t.decimal :other_total, precision: 10, scale: 2, default: 0

      # Calculated P&L
      t.decimal :total_expenses, precision: 10, scale: 2, default: 0
      t.decimal :gross_profit, precision: 10, scale: 2, default: 0
      t.decimal :net_profit, precision: 10, scale: 2, default: 0

      # Subscription metrics
      t.integer :active_subscriptions
      t.integer :new_subscriptions
      t.integer :churned_subscriptions
      t.decimal :mrr, precision: 10, scale: 2, default: 0

      t.datetime :calculated_at

      t.timestamps
    end

    add_index :financial_metrics, [:year, :month], unique: true
  end
end
