# Bundles the numbers the financials dashboard derives from CostModel that
# also mix in revenue (MRR) — kept out of CostModel itself since those are a
# different domain and aren't persisted facts about the cost structure.
class CostModelDashboard
  Trend = Struct.new(:label, :litres, keyword_init: true)

  def initialize(cost_model: CostModel.current, mrr: MrrCalculator.calculate)
    @cost_model = cost_model
    @mrr = mrr
  end

  attr_reader :cost_model, :mrr

  def monthly_total
    cost_model.monthly_total
  end

  # Positive = revenue covers costs with room to spare. Negative = burning cash.
  def burn_gap
    (mrr - monthly_total).round(2)
  end

  def trailing_3mo_avg_litres
    cost_model.trailing_3mo_avg_litres
  end

  # What's actually being charged per litre right now, blending every active
  # subscription's revenue over the real litres collected — distinct from
  # floor_current/floor_target, which are cost-side only.
  def current_avg_rate
    litres = trailing_3mo_avg_litres
    return nil if litres.zero?
    (mrr / litres).round(2)
  end

  # Holding today's average rate constant, how many litres/month would need
  # to be collected to cover monthly_total.
  def litres_needed_to_break_even
    rate = current_avg_rate
    return nil unless rate&.positive?
    (monthly_total / rate).round(1)
  end

  # Real litres collected per calendar month, oldest first, for the last
  # `months` *complete* months — excludes the current, still-in-progress
  # month (see month_to_date_litres/month_to_date_projected_litres for that),
  # so the trend lines up with trailing_3mo_avg_litres.
  def monthly_litres_trend(months = 3)
    months.downto(1).map do |i|
      month_start = i.months.ago.to_date.beginning_of_month
      Trend.new(
        label: month_start.strftime("%b %Y"),
        litres: Collection.total_litres_between(month_start, month_start.end_of_month)
      )
    end
  end
end
