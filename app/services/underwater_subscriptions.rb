# Ranks active, primary (non-satellite) subscriptions by their most recent
# invoice's effective R/L against CostModel's floor_target, for the
# financials dashboard's "who's actually unprofitable" view. Skips
# subscriptions with no invoice yet, or whose invoice has no R/L basis
# (see RandsPerLitre) — e.g. brand-new subs or order-only invoices.
class UnderwaterSubscriptions
  Row = Struct.new(:subscription, :invoice, :result, keyword_init: true)

  def self.call
    Subscription.where(status: :active, primary_subscription_id: nil)
                .includes(:invoices, :user)
                .filter_map { |sub| row_for(sub) }
                .sort_by { |row| row.result.rate }
  end

  def self.underwater
    call.select { |row| row.result.state == :red }
  end

  def self.row_for(sub)
    invoice = sub.invoices.order(issued_date: :desc).first
    return nil unless invoice

    result = RandsPerLitre.for(invoice)
    return nil unless result

    Row.new(subscription: sub, invoice: invoice, result: result)
  end
  private_class_method :row_for
end
