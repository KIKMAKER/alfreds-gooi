# Homepage pricing card math — extracted so the 1/3/6-month duration
# toggle inside each plan card (see pages/home/_pricing.html.erb) doesn't
# triple the referral/discount-code branching the old inline version had.
# Preserves that logic exactly: a referral code is a flat 15% off every
# duration; NEWSOIL26 only discounts the 3-month plan; any other percent-
# or cents-based discount code applies uniformly across durations.
class PlanPricing
  MONTHLY_RATES = {
    "Standard" => { 1 => 260.0, 3 => 220.0, 6 => 180.0 },
    "XL" => { 1 => 300.0, 3 => 270.0, 6 => 240.0 },
  }.freeze

  Quote = Struct.new(:duration, :per_month, :total, :original_per_month, :original_total, :discounted, keyword_init: true) do
    def discounted?
      discounted
    end
  end

  def self.quote(plan:, duration:, referral_code: nil, discount_code: nil, pct: 0.0, amt: 0.0)
    original_per_month = MONTHLY_RATES.fetch(plan).fetch(duration)
    original_total = original_per_month * duration

    total =
      if referral_code.present?
        original_total * 0.85
      elsif discount_code.present?
        if discount_code.upcase == "NEWSOIL26" && duration != 3
          original_total
        elsif pct.positive?
          original_total * (1 - pct)
        else
          [original_total - amt, 0].max
        end
      else
        original_total
      end

    Quote.new(
      duration: duration,
      per_month: total / duration,
      total: total,
      original_per_month: original_per_month,
      original_total: original_total,
      discounted: total < original_total
    )
  end
end
