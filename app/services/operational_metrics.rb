class OperationalMetrics
  BAKKIE_PURCHASE_PRICE    = 232_900.0
  BAKKIE_PURCHASE_DATE     = Date.new(2024, 4, 16)
  BAKKIE_DEPRECIATION_YEARS = 5

  # Hours timing data was unreliable before this point (early bug in the app).
  # Only use recent hours data for cost-per-hour calculations.
  HOURS_RELIABLE_SINCE = 2.months.ago.to_date

  def calculate
    {
      operational:    operational_data,
      bakkie:         bakkie_metrics,
      revenue:        subscription_revenue,
      sustainability: sustainability_scenarios,
      data_quality:   data_quality_notes
    }
  end

  private

  # ── DriversDay queries ─────────────────────────────────────────────────

  def reliable_days
    @reliable_days ||= DriversDay
      .where("date >= ?", HOURS_RELIABLE_SINCE)
      .where.not(start_time: nil)
      .where.not(end_time: nil)
      .where.not(date: nil)
  end

  def days_with_kms
    @days_with_kms ||= DriversDay
      .where.not(start_kms: nil)
      .where.not(end_kms: nil)
      .where.not(date: nil)
  end

  def all_days
    @all_days ||= DriversDay.where.not(date: nil)
  end

  def recent_days_for_stops
    # Last 3 months gives a current picture of route size
    @recent_days_for_stops ||= DriversDay
      .where("date >= ?", 3.months.ago.to_date)
      .where.not(date: nil)
  end

  # ── Per-day averages ────────────────────────────────────────────────────

  def avg_hours_per_day
    return nil if reliable_days.empty?
    hours = reliable_days.map { |d| (d.end_time - d.start_time) / 3600.0 }
    (hours.sum / hours.size).round(2)
  end

  def avg_kms_per_day
    return nil if days_with_kms.empty?
    kms = days_with_kms
      .map { |d| (d.end_kms - d.start_kms).to_f }
      .select { |k| k.positive? && k <= 500 }  # cap at 500 km/day (outlier guard)
    return nil if kms.empty?
    # Use median to stay robust against any remaining outliers
    sorted = kms.sort
    mid = sorted.size / 2
    median = sorted.size.odd? ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2.0)
    median.round(1)
  end

  def avg_stops_per_day
    return nil if recent_days_for_stops.empty?
    counts = recent_days_for_stops.map do |d|
      d.collections.where(skip: false).where.not(is_done: false).count +
        d.collections.where(skip: true).count
    end
    (counts.sum.to_f / counts.size).round(1)
  end

  def avg_buckets_per_day
    days = all_days.where.not(total_buckets: nil).where("total_buckets > 0")
    return nil if days.empty?
    days.average(:total_buckets).to_f.round(1)
  end

  def avg_days_per_month
    return nil if all_days.empty?
    monthly_counts = all_days.group_by { |d| [d.date.year, d.date.month] }.map { |_, days| days.count }
    (monthly_counts.sum.to_f / monthly_counts.size).round(1)
  end

  def monthly_hours
    return nil unless avg_hours_per_day && avg_days_per_month
    (avg_hours_per_day * avg_days_per_month).round(1)
  end

  def monthly_kms
    return nil unless avg_kms_per_day && avg_days_per_month
    (avg_kms_per_day * avg_days_per_month).round(0).to_i
  end

  # ── Cost data (from imported bank statements) ───────────────────────────

  def avg_monthly_costs
    @avg_monthly_costs ||= begin
      # Use last 6 months of expense data, excluding months with zero expenses
      # (months where no bank statements have been imported yet)
      six_months_ago = 6.months.ago
      metrics = FinancialMetric
        .where("(year > ?) OR (year = ? AND month >= ?)",
               six_months_ago.year, six_months_ago.year, six_months_ago.month)
        .where("total_expenses > 0")
      return 0.0 if metrics.empty?
      (metrics.sum(:total_expenses).to_f / metrics.count).round(2)
    end
  end

  def cost_per_hour
    return nil unless monthly_hours&.positive? && avg_monthly_costs.positive?
    (avg_monthly_costs / monthly_hours).round(2)
  end

  def cost_per_km
    return nil unless monthly_kms&.positive? && avg_monthly_costs.positive?
    (avg_monthly_costs / monthly_kms).round(2)
  end

  def cost_per_stop
    return nil unless avg_stops_per_day&.positive? && avg_days_per_month&.positive? && avg_monthly_costs.positive?
    monthly_stops = avg_stops_per_day * avg_days_per_month
    (avg_monthly_costs / monthly_stops).round(2)
  end

  # ── Revenue data (from active subscriptions) ────────────────────────────

  def subscription_revenue
    result = {}
    %i[Standard XL Commercial once_off].each do |plan|
      subs = Subscription.active.where(plan: plan)
      next if subs.empty?

      monthly_amounts = subs.filter_map do |s|
        total = s.monthly_subscription_amount.to_f + s.monthly_volume_amount.to_f
        total.positive? ? total : nil
      end

      result[plan] = {
        count:         subs.count,
        avg_monthly:   monthly_amounts.any? ? (monthly_amounts.sum / monthly_amounts.size).round(2) : 0,
        total_monthly: monthly_amounts.sum.round(2),
        with_amounts:  monthly_amounts.size
      }
    end
    result
  end

  def current_mrr
    subscription_revenue.values.sum { |v| v[:total_monthly] }.round(2)
  end

  # ── Bakkie ──────────────────────────────────────────────────────────────

  def bakkie_metrics
    months_owned      = ((Date.current - BAKKIE_PURCHASE_DATE) / 30.44).floor
    total_months      = BAKKIE_DEPRECIATION_YEARS * 12
    monthly_dep       = (BAKKIE_PURCHASE_PRICE / total_months).round(2)
    book_value        = [BAKKIE_PURCHASE_PRICE - (monthly_dep * months_owned), 0].max.round(2)
    months_remaining  = [total_months - months_owned, 0].max

    {
      purchase_price:       BAKKIE_PURCHASE_PRICE,
      purchase_date:        BAKKIE_PURCHASE_DATE,
      months_owned:         months_owned,
      monthly_depreciation: monthly_dep,
      book_value:           book_value,
      months_remaining:     months_remaining
    }
  end

  # ── Salary sustainability ────────────────────────────────────────────────

  def sustainability_scenarios
    bakkie_monthly    = bakkie_metrics[:monthly_depreciation]
    total_costs       = avg_monthly_costs + bakkie_monthly
    available_now     = current_mrr - total_costs

    # Use avg plan amounts for scenario calculations; fall back to typical prices
    # if no subscriptions have amounts populated yet (nonzero? returns nil for 0)
    std_avg  = subscription_revenue.dig(:Standard, :avg_monthly).to_f.nonzero? || 220.0
    xl_avg   = subscription_revenue.dig(:XL, :avg_monthly).to_f.nonzero?       || 300.0

    target_salaries = [5_000, 7_500, 10_000, 15_000, 20_000, 25_000]
    target_salaries.map do |target|
      gap = [target - available_now, 0].max
      {
        target_salary:         target,
        achievable:            available_now >= target,
        available_now:         available_now.round(2),
        gap:                   gap.round(2),
        extra_standard_needed: gap.positive? ? (gap / std_avg).ceil : 0,
        extra_xl_needed:       gap.positive? ? (gap / xl_avg).ceil  : 0
      }
    end
  end

  # ── Data quality notes ───────────────────────────────────────────────────

  def data_quality_notes
    {
      hours_reliable_since:  HOURS_RELIABLE_SINCE,
      reliable_day_count:    reliable_days.count,
      kms_day_count:         days_with_kms.count,
      total_day_count:       all_days.count,
      earliest_day:          all_days.minimum(:date),
      latest_day:            all_days.maximum(:date),
      bank_data_present:     avg_monthly_costs.positive?
    }
  end

  def operational_data
    {
      avg_hours_per_day:  avg_hours_per_day,
      avg_kms_per_day:    avg_kms_per_day,
      avg_stops_per_day:  avg_stops_per_day,
      avg_buckets_per_day: avg_buckets_per_day,
      avg_days_per_month: avg_days_per_month,
      monthly_hours:      monthly_hours,
      monthly_kms:        monthly_kms,
      cost_per_hour:      cost_per_hour,
      cost_per_km:        cost_per_km,
      cost_per_stop:      cost_per_stop,
      avg_monthly_costs:  avg_monthly_costs,
      current_mrr:        current_mrr
    }
  end
end
