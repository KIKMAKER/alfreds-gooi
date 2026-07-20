# Deterministic expected-litres-per-month for a plan — the volume side of
# contracted_r_per_litre (see RandsPerLitre). Identical for every
# subscription on the same plan (Commercial: same bucket size/frequency
# too), regardless of collection history or subscription age. Never derived
# from actual Collection data — that's what makes it "expected" rather than
# "realised".
module PlanVolume
  WEEKS_PER_MONTH = 4

  # Standard/XL are flat-rate plans where actual pickup cadence varies
  # customer to customer, so a per-customer contracted frequency doesn't
  # exist to multiply out — these are real seeded business averages instead.
  STANDARD_EXPECTED_MONTHLY_LITRES = 18.0 # 5L bags
  XL_EXPECTED_MONTHLY_LITRES       = 62.0 # 25L buckets

  # Expected monthly litres for a subscription. Commercial is derived from
  # the subscription's own quoted bucket size/frequency; Standard/XL from
  # the seeded averages above. Includes satellite subscriptions' volume,
  # since billing flows entirely through the primary (satellites never
  # invoice independently — see Subscription#satellite?) but their volume is
  # still part of what the primary's price is covering. Returns nil for
  # once_off, which has no ongoing monthly rate.
  def self.expected_monthly_litres(subscription)
    own = plan_monthly_litres(subscription)
    return nil unless own

    satellite_litres = subscription.satellite_subscriptions.sum { |s| plan_monthly_litres(s).to_f }
    own + satellite_litres
  end

  # Same idea for a quotation that hasn't become a subscription yet —
  # derived purely from the quote's own line items (bucket size × qty ×
  # frequency), never from collections, since a quote has no collection
  # history to draw on in the first place.
  def self.expected_monthly_litres_for_quotation(quotation)
    return nil if quotation.event?

    per_collection =
      if quotation.buckets_per_collection && quotation.inferred_bucket_size
        quotation.buckets_per_collection * quotation.inferred_bucket_size
      elsif quotation.subscription
        quotation.subscription.allowed_litres_per_collection
      end
    return nil unless per_collection&.positive?

    per_collection * quotation.effective_collections_per_week * WEEKS_PER_MONTH
  end

  def self.plan_monthly_litres(subscription)
    case subscription.plan
    when "Standard" then STANDARD_EXPECTED_MONTHLY_LITRES
    when "XL" then XL_EXPECTED_MONTHLY_LITRES
    when "Commercial" then commercial_monthly_litres(subscription)
    end
  end
  private_class_method :plan_monthly_litres

  def self.commercial_monthly_litres(subscription)
    per_collection = (subscription.buckets_per_collection || 1) * (subscription.bucket_size || 45)
    per_collection * (subscription.collections_per_week || 1) * WEEKS_PER_MONTH
  end
  private_class_method :commercial_monthly_litres
end
