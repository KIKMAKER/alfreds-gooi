class FinancialMetricsCalculator
  def initialize(year, month)
    @year = year
    @month = month
    @month_start = Date.new(@year, @month, 1)
    @month_end = @month_start.end_of_month
  end

  def calculate
    metric_data = {
      year: @year,
      month: @month,
      calculated_at: Time.current
    }

    # Calculate all components
    metric_data.merge!(calculate_revenue)
    metric_data.merge!(calculate_expenses)
    metric_data.merge!(calculate_profit)
    metric_data.merge!(calculate_subscription_metrics)

    # Upsert to database
    FinancialMetric.upsert(metric_data, unique_by: [:year, :month])

    FinancialMetric.find_by(year: @year, month: @month)
  end

  private

  def calculate_revenue
    # Cash revenue: invoices actually paid in this month
    cash_revenue = calculate_cash_revenue

    # Accrual revenue: revenue recognized for this month (service delivered)
    recognized_revenue = RevenueRecognition
      .where(period_year: @year, period_month: @month)
      .sum(:recognized_amount)
      .to_f

    {
      cash_revenue: cash_revenue,
      recognized_revenue: recognized_revenue
    }
  end

  def calculate_cash_revenue
    # Get invoices paid in this month
    Invoice.joins(:payments)
      .where(paid: true)
      .where(payments: { date: @month_start..@month_end })
      .distinct
      .sum(:total_amount)
      .to_f
  end

  def calculate_expenses
    # Get all expenses for this month
    expenses = Expense.where(accounting_year: @year, accounting_month: @month)

    # Group by category group
    cogs_total = expenses.cogs.sum(:amount).to_f
    operational_total = expenses.operational.sum(:amount).to_f
    fixed_total = expenses.fixed_costs.sum(:amount).to_f
    marketing_total = expenses.marketing_costs.sum(:amount).to_f
    admin_total = expenses.admin_costs.sum(:amount).to_f

    # Calculate "other" - anything not in the above categories
    other_total = expenses.where(category: 99).sum(:amount).to_f

    total_expenses = cogs_total + operational_total + fixed_total +
                     marketing_total + admin_total + other_total

    {
      cogs_total: cogs_total,
      operational_total: operational_total,
      fixed_total: fixed_total,
      marketing_total: marketing_total,
      admin_total: admin_total,
      other_total: other_total,
      total_expenses: total_expenses
    }
  end

  def calculate_profit
    # Use recognized revenue for profit calculations (accrual basis)
    recognized_revenue = RevenueRecognition
      .where(period_year: @year, period_month: @month)
      .sum(:recognized_amount)
      .to_f

    cogs = Expense.where(accounting_year: @year, accounting_month: @month)
                  .cogs
                  .sum(:amount)
                  .to_f

    total_expenses = Expense.where(accounting_year: @year, accounting_month: @month)
                            .sum(:amount)
                            .to_f

    gross_profit = recognized_revenue - cogs
    net_profit = recognized_revenue - total_expenses

    {
      gross_profit: gross_profit,
      net_profit: net_profit
    }
  end

  def calculate_subscription_metrics
    # Active subscriptions at end of month
    active_subs = Subscription.active
      .where("start_date <= ?", @month_end)
      .count

    # New subscriptions started in this month
    new_subs = Subscription
      .where(start_date: @month_start..@month_end)
      .where(status: [:active, :pending])
      .count

    # Churned subscriptions (completed in this month)
    churned_subs = Subscription
      .where(status: :completed)
      .where("updated_at >= ? AND updated_at <= ?", @month_start, @month_end)
      .count

    # MRR at end of month
    mrr = MrrCalculator.calculate(@month_end)

    {
      active_subscriptions: active_subs,
      new_subscriptions: new_subs,
      churned_subscriptions: churned_subs,
      mrr: mrr
    }
  end
end
