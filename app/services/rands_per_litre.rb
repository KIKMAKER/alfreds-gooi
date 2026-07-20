# Two distinct R/L metrics, named consistently everywhere they're used:
#
# - contracted_r_per_litre = monthly_charge ÷ expected_monthly_litres (see
#   PlanVolume). Deterministic: identical for any two subscriptions on the
#   same plan and price, regardless of subscription age or collection
#   history. This is what the quote/invoice pill, the underwater-
#   subscriptions ranking, and the cost floor comparison all use.
# - realised_r_per_litre = actual revenue ÷ actual litres collected, over
#   the last 3 *complete* calendar months, only computed for subscriptions
#   that were active the whole window. Diagnostic only — shows who is
#   under/over-delivering litres relative to what their plan assumes.
#
# Both exclude one-off charges (starter kits, once-off collections) from the
# revenue side in one place: monthly_charge reads only the cached recurring
# fields (monthly_subscription_amount/monthly_volume_amount), which
# InvoiceBuilder already keeps separate from starter_kit_installment.
class RandsPerLitre
  # state is one of :green (at/above price_guidance), :amber (between floor_target
  # and price_guidance), :red (below floor_target), or nil (no cost floor set,
  # i.e. CostModel#target_monthly_litres is 0 — nothing to compare against).
  Result = Struct.new(:rate, :litres, :note, :floor_target, :price_guidance,
                      :target_monthly_litres, :state, :realised_rate, keyword_init: true)

  def self.for(record)
    case record
    when Subscription then for_subscription(record)
    when Quotation then for_quotation(record)
    when Invoice then for_invoice(record)
    end
  end

  def self.for_subscription(subscription)
    charge = monthly_charge(subscription)
    litres = PlanVolume.expected_monthly_litres(subscription)
    return nil unless charge&.positive? && litres&.positive?

    build(charge, litres, "R#{format('%.2f', charge)}/mo ÷ #{litres}L/mo (plan average)",
          realised_rate: realised_r_per_litre(subscription))
  end

  def self.for_quotation(quotation)
    return nil if quotation.event?

    charge = quotation.ongoing_monthly_rate
    return nil unless charge.to_f.positive?

    litres = PlanVolume.expected_monthly_litres_for_quotation(quotation)
    return nil unless litres&.positive?

    build(charge, litres, "R#{format('%.2f', charge)}/mo ÷ #{litres}L/mo")
  end

  # Every invoice for a given subscription shows the *same* contracted rate —
  # which invoice happens to be "most recent" no longer affects the number.
  def self.for_invoice(invoice)
    return nil if invoice.order_id.present?

    sub = invoice.subscription
    return nil unless sub

    for_subscription(sub)
  end

  # Diagnostic: actual revenue ÷ actual litres over the last 3 complete
  # calendar months, only for subscriptions active the entire window (a
  # subscription that started or ended mid-window hasn't had a fair chance
  # to deliver a full 3 months of volume). nil whenever there's nothing
  # meaningful to compare — new subscriptions, once_off, no real litres.
  def self.realised_r_per_litre(subscription)
    charge = monthly_charge(subscription)
    return nil unless charge&.positive?

    range = CostModel.complete_months_range(3)
    return nil unless active_for_whole_window?(subscription, range)

    litres = subscription.total_litres_between(range.first, range.last)
    return nil unless litres.to_f.positive?

    (charge * 3 / litres).round(2)
  end

  # The subscription's real recurring monthly charge — excludes the starter
  # kit installment (a one-off cost InvoiceBuilder already tracks separately
  # from these fields) and doesn't depend on whether/which invoice has been
  # generated. nil until the subscription has been billed at least once,
  # since that's when these cached fields are first established.
  def self.monthly_charge(subscription)
    return nil if subscription.once_off?

    amount = subscription.monthly_subscription_amount.to_f + subscription.monthly_volume_amount.to_f
    amount.positive? ? amount : nil
  end
  private_class_method :monthly_charge

  def self.active_for_whole_window?(subscription, range)
    start = subscription.start_date&.to_date
    return false unless start && start <= range.first

    finish = subscription.end_date&.to_date
    return false if finish && finish < range.last

    true
  end
  private_class_method :active_for_whole_window?

  def self.build(total, litres, basis, realised_rate: nil)
    return nil unless litres.to_f.positive?

    rate = (total.to_f / litres).round(2)
    cost_model = CostModel.current
    floor_target = cost_model.floor_target
    price_guidance = cost_model.price_guidance

    Result.new(
      rate: rate,
      litres: litres,
      note: "R#{format('%.2f', total.to_f)} ÷ #{litres}L (#{basis})",
      floor_target: floor_target,
      price_guidance: price_guidance,
      target_monthly_litres: cost_model.target_monthly_litres,
      state: classify(rate, floor_target, price_guidance),
      realised_rate: realised_rate
    )
  end
  private_class_method :build

  def self.classify(rate, floor_target, price_guidance)
    return nil unless floor_target && price_guidance
    return :green if rate >= price_guidance
    return :amber if rate >= floor_target
    :red
  end
  private_class_method :classify
end
