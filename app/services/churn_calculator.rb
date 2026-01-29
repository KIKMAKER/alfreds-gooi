class ChurnCalculator
  def initialize(start_date: 3.months.ago.beginning_of_month, end_date: Date.current.end_of_month)
    @start_date = start_date
    @end_date = end_date
  end

  # Calculate churn rate for a specific month
  def self.monthly_churn(year, month)
    start_of_month = Date.new(year, month, 1)
    end_of_month = start_of_month.end_of_month

    # Users with active subscriptions at start of month
    users_at_start = active_users_on_date(start_of_month)

    # Users with active subscriptions at end of month
    users_at_end = active_users_on_date(end_of_month)

    # Churned users = had active sub at start but not at end
    churned_users = users_at_start - users_at_end

    return 0 if users_at_start.empty?

    churn_rate = (churned_users.count.to_f / users_at_start.count * 100).round(2)

    {
      month: start_of_month,
      users_at_start: users_at_start.count,
      users_at_end: users_at_end.count,
      churned_users: churned_users.count,
      churn_rate: churn_rate
    }
  end

  # Calculate average churn rate over a period (month-by-month)
  def average_churn_rate
    monthly_rates = []
    current = @start_date

    while current <= @end_date
      result = self.class.monthly_churn(current.year, current.month)
      monthly_rates << result[:churn_rate] if result[:users_at_start] > 0
      current = current.next_month
    end

    return 0 if monthly_rates.empty?

    (monthly_rates.sum / monthly_rates.count.to_f).round(2)
  end

  # Calculate churn over the entire period (start to end)
  # More forgiving - gives users time to come back
  def period_churn_rate
    users_at_start = self.class.active_users_on_date(@start_date)
    users_at_end = self.class.active_users_on_date(@end_date)

    churned_users = users_at_start - users_at_end

    return 0 if users_at_start.empty?

    churn_rate = (churned_users.count.to_f / users_at_start.count * 100).round(2)

    {
      period: "#{@start_date.strftime('%b %Y')} - #{@end_date.strftime('%b %Y')}",
      users_at_start: users_at_start.count,
      users_at_end: users_at_end.count,
      churned_users: churned_users.count,
      churn_rate: churn_rate,
      # Normalize to monthly rate for forecasting
      monthly_churn_rate: normalize_to_monthly_rate(churn_rate)
    }
  end

  # Get detailed churn history
  def churn_history
    history = []
    current = @start_date

    while current <= @end_date
      history << self.class.monthly_churn(current.year, current.month)
      current = current.next_month
    end

    history
  end

  private

  def normalize_to_monthly_rate(period_churn_rate)
    # Convert period churn rate to monthly equivalent
    # If 10% churned over 3 months, monthly rate = 1 - (0.9)^(1/3)
    months = ((@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)).to_f
    return period_churn_rate if months <= 1

    retention_rate = 1 - (period_churn_rate / 100.0)
    monthly_retention = retention_rate ** (1.0 / months)
    monthly_churn = (1 - monthly_retention) * 100

    monthly_churn.round(2)
  end

  def self.active_users_on_date(date)
    # Find all users who have at least one active subscription on this date
    User.joins(:subscriptions)
        .where("subscriptions.start_date <= ?", date)
        .where("subscriptions.end_date IS NULL OR subscriptions.end_date >= ?", date)
        .where(subscriptions: { status: :active })
        .distinct
        .pluck(:id)
  end
end
