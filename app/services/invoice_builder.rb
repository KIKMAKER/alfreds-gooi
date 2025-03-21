# app/services/invoice_builder.rb
class InvoiceBuilder
  def initialize(subscription:, og: false, is_new: false, referee: nil, referred_friends: 0)
    @subscription = subscription
    @og = og
    @is_new = is_new
    @referee = referee
    @referred_friends = referred_friends
  end

  def call
    invoice = Invoice.create!(
      subscription: @subscription,
      issued_date: Time.current,
      due_date: Time.current + 2.weeks,
      total_amount: 0
    )

    add_starter_kit(invoice) if @is_new
    add_subscription_product(invoice)
    apply_discounts(invoice)

    invoice.calculate_total
    invoice
  end

  private

  def add_starter_kit(invoice)
    kit = Product.find_by(title: "#{@subscription.plan} Starter Kit")
    invoice.invoice_items.create!(product: kit, quantity: 1, amount: kit.price)
  end

  def add_subscription_product(invoice)
    title = if @og
      "#{@subscription.plan} #{@subscription.duration} month OG subscription"
    else
      "#{@subscription.plan} #{@subscription.duration} month subscription"
    end

    product = Product.find_by(title: title)
    raise "Product not found: #{title}" unless product

    invoice.invoice_items.create!(product: product, quantity: 1, amount: product.price)
  end

  def apply_discounts(invoice)
    if @referred_friends&.positive?
      discount = Product.find_by(title: "Referred a friend discount")
      invoice.invoice_items.create!(
        product: discount,
        quantity: @referred_friends,
        amount: discount.price
      )
      mark_referrals_used
    elsif @referee
      title = "Referral discount #{@subscription.plan} #{@subscription.duration} month"
      discount = Product.find_by(title: title)
      invoice.invoice_items.create!(product: discount, quantity: 1, amount: discount.price)

      Referral.create!(
        subscription: @subscription,
        referee: @subscription.user,
        referrer: @referee,
        status: :pending
      )
    end
  end

  def mark_referrals_used
    @subscription.user.referrals_as_referrer.completed.each(&:used!)
  end
end
