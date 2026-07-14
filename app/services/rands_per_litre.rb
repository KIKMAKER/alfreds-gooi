# Contracted rand-per-litre for an invoice or quotation: total charged ÷
# litres of collection capacity over the period the document covers.
#
# Uses contracted volume (allowed litres × collections/week × weeks), not
# actual collected litres — quotes and fresh invoices have no collections
# yet. Weeks follow the billing convention of 4 per month (see
# Quotation#weeks_in_contract and next_invoice_date advancing 4 weeks).
#
# Returns nil when the document has no volume basis (order invoices, event
# quotes, zero totals, missing bucket config) — callers hide the badge.
class RandsPerLitre
  WEEKS_PER_MONTH = 4

  Result = Struct.new(:rate, :litres, :note, keyword_init: true)

  def self.for(record)
    case record
    when Invoice then for_invoice(record)
    when Quotation then for_quotation(record)
    end
  end

  def self.for_invoice(invoice)
    return nil if invoice.total_amount.to_f <= 0
    return nil if invoice.order_id.present?

    sub = invoice.subscription
    return nil unless sub

    if sub.once_off?
      litres = sub.allowed_litres_per_collection
      build(invoice.total_amount, litres, "1 once-off collection")
    elsif sub.monthly_invoicing?
      subs = billed_monthly_subs(sub)
      weekly = subs.sum { |s| with_satellites(s).sum(&:expected_weekly_volume_l) }
      note = "#{WEEKS_PER_MONTH} weeks × #{weekly}L/week"
      note += " across #{subs.size} subscriptions" if subs.size > 1
      build(invoice.total_amount, weekly * WEEKS_PER_MONTH, note)
    else
      return nil unless sub.duration&.positive?

      weekly = with_satellites(sub).sum(&:expected_weekly_volume_l)
      weeks = sub.duration * WEEKS_PER_MONTH
      build(invoice.total_amount, weekly * weeks, "#{weeks} weeks × #{weekly}L/week")
    end
  end

  def self.for_quotation(quotation)
    return nil if quotation.event?
    return nil if quotation.total_amount.to_f <= 0

    per_collection =
      if quotation.buckets_per_collection && quotation.inferred_bucket_size
        quotation.buckets_per_collection * quotation.inferred_bucket_size
      elsif quotation.subscription
        quotation.subscription.allowed_litres_per_collection
      end
    return nil unless per_collection&.positive?

    weekly = per_collection * quotation.effective_collections_per_week
    weeks = quotation.weeks_in_contract
    return nil unless weeks.positive?

    build(quotation.total_amount, weekly * weeks, "#{weeks} weeks × #{weekly}L/week")
  end

  # Monthly invoices can combine every active monthly subscription the user
  # has (MonthlyInvoiceService merges same-day billing into one invoice), so
  # litres must count them all — e.g. Loading Bay's two locations on one
  # invoice. Falls back to the invoice's own subscription for historical
  # invoices whose subscription is no longer active.
  def self.billed_monthly_subs(sub)
    siblings = sub.user.subscriptions
                  .where(monthly_invoicing: true, status: :active, primary_subscription_id: nil)
                  .to_a
    siblings.include?(sub) ? siblings : [sub]
  end
  private_class_method :billed_monthly_subs

  def self.with_satellites(sub)
    [sub] + sub.satellite_subscriptions.to_a
  end
  private_class_method :with_satellites

  def self.build(total, litres, basis)
    return nil unless litres.to_f.positive?

    Result.new(
      rate: (total.to_f / litres).round(2),
      litres: litres,
      note: "R#{format('%.2f', total.to_f)} ÷ #{litres}L (#{basis})"
    )
  end
  private_class_method :build
end
