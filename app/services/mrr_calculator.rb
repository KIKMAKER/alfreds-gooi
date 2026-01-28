class MrrCalculator
  def self.calculate(date = Date.current)
    active_subs = Subscription.active
      .where("start_date <= ?", date)

    total_mrr = 0.0

    active_subs.each do |sub|
      monthly_value = calculate_monthly_value(sub)
      total_mrr += monthly_value if monthly_value
    end

    total_mrr.round(2)
  end

  private

  def self.calculate_monthly_value(subscription)
    # For monthly invoicing subscriptions
    if subscription.monthly_invoicing? && subscription.contract_total
      return subscription.contract_total / subscription.duration
    end

    # For prepaid subscriptions, get the product price
    product_title = "#{subscription.plan} #{subscription.duration} month subscription"
    product = Product.find_by(title: product_title)

    return 0 unless product&.price

    # Amortize over duration
    product.price / subscription.duration
  end
end
