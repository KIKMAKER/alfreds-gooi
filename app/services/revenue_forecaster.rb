class RevenueForecaster
  def initialize(forecast_months: 6, churn_rate: 0.05)
    @forecast_months = forecast_months
    @churn_rate = churn_rate  # Default 5% monthly churn
  end

  def forecast
    forecasts = []
    start_date = Date.current.beginning_of_month

    @forecast_months.times do |i|
      month_date = start_date + i.months

      forecasts << {
        month: month_date,
        month_label: month_date.strftime("%B %Y"),
        committed_revenue: committed_revenue_for_month(month_date),
        expected_revenue: expected_revenue_for_month(month_date, i),
        projected_active_subs: projected_active_subs(month_date, i)
      }
    end

    forecasts
  end

  private

  def committed_revenue_for_month(month_date)
    # Revenue from subscriptions that will definitely be active
    RevenueRecognition
      .where(period_year: month_date.year, period_month: month_date.month)
      .sum(:recognized_amount)
      .to_f
  end

  def expected_revenue_for_month(month_date, months_ahead)
    committed = committed_revenue_for_month(month_date)

    # Apply churn decay
    churn_multiplier = (1 - @churn_rate) ** months_ahead

    (committed * churn_multiplier).round(2)
  end

  def projected_active_subs(month_date, months_ahead)
    # Current active subscriptions
    current_active = Subscription.active.count

    # Apply churn
    after_churn = current_active * ((1 - @churn_rate) ** months_ahead)

    # Add estimated new customers
    avg_new_per_month = calculate_avg_new_per_month
    projected = after_churn + (avg_new_per_month * months_ahead)

    projected.round
  end

  def calculate_avg_new_per_month
    # Calculate average new subscriptions over last 3 months
    three_months_ago = 3.months.ago.beginning_of_month

    new_subs_count = Subscription
      .where("start_date >= ?", three_months_ago)
      .where(status: [:active, :pending])
      .count

    (new_subs_count / 3.0).round(1)
  end
end
