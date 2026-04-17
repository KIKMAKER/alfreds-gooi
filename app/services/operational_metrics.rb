class OperationalMetrics
  BAKKIE_PURCHASE_PRICE    = 232_900.0
  BAKKIE_PURCHASE_DATE     = Date.new(2024, 4, 16)
  BAKKIE_DEPRECIATION_YEARS = 5

  # Hours timing data was unreliable before this point (early bug in the app).
  # Only use recent hours data for cost-per-hour calculations.
  HOURS_RELIABLE_SINCE = 2.months.ago.to_date

  def calculate
    {
      operational:       operational_data,
      bakkie:            bakkie_metrics,
      revenue:           subscription_revenue,
      litre_pricing:     price_per_litre_by_plan,
      sustainability:    sustainability_scenarios,
      data_quality:      data_quality_notes
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
    counts = recent_days_for_stops.map { |d| d.collections.where(skip: false).count }
    (counts.sum.to_f / counts.size).round(1)
  end

  # Stops per hour derived from the same reliable-hours window so both sides
  # of the ratio come from identical days.
  def stops_per_hour
    return nil if reliable_days.empty?
    total_hours = reliable_days.sum { |d| (d.end_time - d.start_time) / 3600.0 }
    return nil unless total_hours.positive?
    total_stops = reliable_days.sum { |d| d.collections.where(skip: false).count }
    (total_stops.to_f / total_hours).round(2)
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
      subs = Subscription.active.where(plan: plan).includes(:invoices)
      next if subs.empty?

      monthly_amounts = subs.filter_map { |s| effective_monthly_amount(s) }

      result[plan] = {
        count:         subs.count,
        avg_monthly:   monthly_amounts.any? ? (monthly_amounts.sum / monthly_amounts.size).round(2) : 0,
        total_monthly: monthly_amounts.sum.round(2),
        with_amounts:  monthly_amounts.size
      }
    end
    result
  end

  # Returns the effective monthly charge for a subscription.
  # Three-level fallback:
  #   1. Explicit monthly amounts stored at invoice creation (newest subscriptions)
  #   2. contract_total / duration (set on many subscriptions at signup)
  #   3. Implied from avg of last 2 paid invoices:
  #        - monthly_invoicing? → invoice amount IS the monthly charge
  #        - upfront billing    → invoice amount / duration = monthly charge
  def effective_monthly_amount(sub)
    # 1. Explicit monthly amounts stored at invoice creation (newest subscriptions)
    explicit = sub.monthly_subscription_amount.to_f + sub.monthly_volume_amount.to_f
    return explicit if explicit.positive?

    # 2. Implied from avg of last 2 paid invoices — preferred over contract_total
    #    because contract_total is derived from product prices at signup, which may
    #    not match negotiated rates (especially for Commercial clients on quotations).
    paid = sub.invoices.select(&:paid).sort_by { |i| i.issued_date || Date.new(2000) }.last(2)
    if paid.any?
      avg_invoice = paid.sum(&:total_amount).to_f / paid.size
      if avg_invoice.positive?
        monthly = if sub.monthly_invoicing?
                    avg_invoice
                  elsif sub.duration.to_f.positive?
                    avg_invoice / sub.duration.to_f
                  else
                    avg_invoice
                  end
        return monthly.round(2)
      end
    end

    # 3. contract_total / duration as last resort (product-price-based, may be stale)
    if sub.contract_total.to_f.positive? && sub.duration.to_f.positive?
      (sub.contract_total.to_f / sub.duration.to_f).round(2)
    end
  end

  # ── Price per litre by plan ─────────────────────────────────────────────

  def price_per_litre_by_plan
    three_months_ago = 3.months.ago.to_date
    result = {}

    # Standard — volume unit is bags (5L each)
    std_subs = Subscription.active.where(plan: :Standard)
    if std_subs.any?
      std_ids = std_subs.pluck(:id)

      # Avg litres per active collection in recent 3 months
      std_cols = Collection.where(subscription_id: std_ids, skip: false)
                           .where("date >= ?", three_months_ago)
                           .where("bags > 0")
      avg_litres = if std_cols.any?
                     (std_cols.sum("bags * 5").to_f / std_cols.count).round(1)
                   else
                     5.0  # 1 standard bag fallback
                   end

      # Avg collections per subscription per month over last 3 months
      avg_cols_per_month = collections_per_month(std_ids, three_months_ago)
      monthly_litres     = (avg_litres * avg_cols_per_month).round(1)

      avg_monthly = subscription_revenue.dig(:Standard, :avg_monthly).to_f.nonzero? || 220.0

      result[:Standard] = {
        volume_unit:          "bag (5L)",
        avg_litres_per_visit: avg_litres,
        avg_visits_per_month: avg_cols_per_month,
        avg_litres_per_month: monthly_litres,
        avg_monthly_charge:   avg_monthly,
        total_monthly_revenue: subscription_revenue.dig(:Standard, :total_monthly).to_f,
        active_count:         std_subs.count,
        price_per_litre:      monthly_litres.positive? ? (avg_monthly / monthly_litres).round(2) : nil
      }
    end

    # XL — volume unit is 25L buckets
    xl_subs = Subscription.active.where(plan: :XL)
    if xl_subs.any?
      xl_ids = xl_subs.pluck(:id)

      xl_cols = Collection.where(subscription_id: xl_ids, skip: false)
                          .where("date >= ?", three_months_ago)
                          .where("buckets > 0 OR buckets_25l > 0 OR buckets_45l > 0")
      avg_litres = if xl_cols.any?
                     # Use actual sizes where recorded; fall back to buckets × 25 per row
                     total = xl_cols.sum("CASE WHEN (buckets_25l + buckets_45l) > 0 THEN buckets_25l * 25 + buckets_45l * 45 ELSE buckets * 25 END")
                     (total.to_f / xl_cols.count).round(1)
                   else
                     25.0  # 1 × 25L bucket fallback
                   end

      avg_cols_per_month = collections_per_month(xl_ids, three_months_ago)
      monthly_litres     = (avg_litres * avg_cols_per_month).round(1)

      avg_monthly = subscription_revenue.dig(:XL, :avg_monthly).to_f.nonzero? || 300.0

      result[:XL] = {
        volume_unit:          "25L bucket",
        avg_litres_per_visit: avg_litres,
        avg_visits_per_month: avg_cols_per_month,
        avg_litres_per_month: monthly_litres,
        avg_monthly_charge:   avg_monthly,
        total_monthly_revenue: subscription_revenue.dig(:XL, :total_monthly).to_f,
        active_count:         xl_subs.count,
        price_per_litre:      monthly_litres.positive? ? (avg_monthly / monthly_litres).round(2) : nil
      }
    end

    # Commercial — volume unit is 25L or 45L buckets (tracked explicitly)
    com_subs = Subscription.active.where(plan: :Commercial)
    if com_subs.any?
      com_ids = com_subs.pluck(:id)

      com_cols = Collection.where(subscription_id: com_ids, skip: false)
                           .where("date >= ?", three_months_ago)
                           .where("buckets_25l > 0 OR buckets_45l > 0")
      avg_litres = if com_cols.any?
                     (com_cols.sum("buckets_25l * 25 + buckets_45l * 45").to_f / com_cols.count).round(1)
                   else
                     45.0  # 1 × 45L bucket fallback
                   end

      avg_cols_per_month = collections_per_month(com_ids, three_months_ago)
      monthly_litres     = (avg_litres * avg_cols_per_month).round(1)

      avg_monthly = subscription_revenue.dig(:Commercial, :avg_monthly).to_f.nonzero? || 500.0

      result[:Commercial] = {
        volume_unit:          "25L/45L bucket",
        avg_litres_per_visit: avg_litres,
        avg_visits_per_month: avg_cols_per_month,
        avg_litres_per_month: monthly_litres,
        avg_monthly_charge:   avg_monthly,
        total_monthly_revenue: subscription_revenue.dig(:Commercial, :total_monthly).to_f,
        active_count:         com_subs.count,
        price_per_litre:      monthly_litres.positive? ? (avg_monthly / monthly_litres).round(2) : nil
      }
    end

    result
  end

  # Average active collections per subscription per month over a window.
  # Uses SQL aggregation rather than loading every collection record.
  def collections_per_month(subscription_ids, since_date)
    months_in_window = ((Date.current - since_date) / 30.44).round.clamp(1, 36).to_f

    total_cols = Collection
      .where(subscription_id: subscription_ids, skip: false)
      .where("date >= ?", since_date)
      .count

    return 4.0 if total_cols.zero?  # fallback: weekly service ≈ 4/month

    # Total collections / number of subs / months in window
    (total_cols.to_f / subscription_ids.size / months_in_window).round(2)
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
      avg_hours_per_day:   avg_hours_per_day,
      avg_kms_per_day:     avg_kms_per_day,
      avg_stops_per_day:   avg_stops_per_day,
      stops_per_hour:      stops_per_hour,
      avg_buckets_per_day: avg_buckets_per_day,
      avg_days_per_month:  avg_days_per_month,
      monthly_hours:       monthly_hours,
      monthly_kms:         monthly_kms,
      cost_per_hour:       cost_per_hour,
      cost_per_km:         cost_per_km,
      cost_per_stop:       cost_per_stop,
      avg_monthly_costs:   avg_monthly_costs,
      current_mrr:         current_mrr
    }
  end
end
