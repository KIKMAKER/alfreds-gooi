# Ranks active, primary (non-satellite) subscriptions by contracted_r_per_litre
# against CostModel's floor_target, for the financials dashboard's "who's
# actually unprofitable" view. Computed directly from the subscription (see
# RandsPerLitre.for_subscription) rather than picking an invoice, so the
# ranking is identical for a subscription regardless of its age or which
# invoice happens to exist. Skips subscriptions with no contracted rate yet
# (never billed, or once_off — see RandsPerLitre).
class UnderwaterSubscriptions
  Row = Struct.new(:subscription, :result, keyword_init: true)

  def self.call
    Subscription.where(status: :active, primary_subscription_id: nil)
                .includes(:user, :satellite_subscriptions)
                .filter_map { |sub| row_for(sub) }
                .sort_by { |row| row.result.rate }
  end

  def self.underwater
    call.select { |row| row.result.state == :red }
  end

  def self.row_for(sub)
    result = RandsPerLitre.for(sub)
    return nil unless result

    Row.new(subscription: sub, result: result)
  end
  private_class_method :row_for
end
