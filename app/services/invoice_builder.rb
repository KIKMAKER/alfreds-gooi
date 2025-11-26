# app/services/invoice_builder.rb
class InvoiceBuilder
  def initialize(subscription: nil, subscriptions: nil, og: false, is_new: false, referee: nil, referred_friends: 0)
    # Accept either a single subscription or multiple subscriptions
    @subscriptions = subscriptions || [subscription].compact
    raise ArgumentError, "At least one subscription required" if @subscriptions.empty?

    @subscription = @subscriptions.first # Keep for backwards compatibility
    @og = og
    @is_new = is_new
    @referee = referee
    @referred_friends = referred_friends
  end

  def call
    invoice = Invoice.create!(
      subscription: @subscription, # Link to first subscription for now
      issued_date: Time.current,
      due_date: Time.current + 2.weeks,
      total_amount: 0
    )

    # Add items for each subscription
    @subscriptions.each do |sub|
      add_starter_kit(invoice, sub) if @is_new
      add_subscription_product(invoice, sub)
    end

    apply_referrals(invoice)
    invoice.calculate_total
    apply_discount_code(invoice) if @subscription.discount_code

    InvoiceMailer.with(invoice: invoice).invoice_created.deliver_now

    invoice
  end

  private

  def add_starter_kit(invoice, subscription)
    kit = Product.find_by(title: "#{subscription.plan} Starter Kit")

    # For commercial subscriptions, add starter kit quantity based on buckets_per_collection
    quantity = subscription.Commercial? ? subscription.buckets_per_collection : 1

    invoice.invoice_items.create!(product: kit, quantity: quantity, amount: kit.price)
  end

  def add_subscription_product(invoice, subscription)
    if subscription.Commercial?
      add_commercial_subscription(invoice, subscription)
    else
      title = if @og
                "#{subscription.plan} #{subscription.duration} month OG subscription"
              else
                "#{subscription.plan} #{subscription.duration} month subscription"
              end

      product = Product.find_by(title: title)
      raise "Product not found: #{title}" unless product

      invoice.invoice_items.create!(product: product, quantity: 1, amount: product.price)
    end
  end

  def add_commercial_subscription(invoice, subscription)
    total_collections = (subscription.duration * 52.0 / 12.0).round

    # Line 1: Monthly collection fee (duration-specific pricing)
    monthly_title = case subscription.duration
                    when 12
                      "Commercial weekly collection per month (12-month rate)"
                    when 6
                      "Commercial weekly collection per month (6-month rate)"
                    when 3
                      "Commercial weekly collection per month (3-month rate)"
                    else
                      raise "Unsupported duration for Commercial subscription: #{subscription.duration}"
                    end

    monthly_product = Product.find_by(title: monthly_title)
    raise "Product not found: #{monthly_title}" unless monthly_product

    invoice.invoice_items.create!(
      product: monthly_product,
      quantity: subscription.duration,
      amount: monthly_product.price
    )

    # Line 2: Volume charge per 45L bucket (duration-specific pricing)
    volume_title = case subscription.duration
                   when 12
                     "Commercial volume per 45L (12-month rate)"
                   when 6
                     "Commercial volume per 45L (6-month rate)"
                   when 3
                     "Commercial volume per 45L (3-month rate)"
                   else
                     raise "Unsupported duration for Commercial subscription: #{subscription.duration}"
                   end

    volume_product = Product.find_by(title: volume_title)
    raise "Product not found: #{volume_title}" unless volume_product

    invoice.invoice_items.create!(
      product: volume_product,
      quantity: total_collections,
      amount: subscription.buckets_per_collection * volume_product.price
    )
  end

  def apply_referrals(invoice)
    if @referred_friends&.positive?
      discount = Product.find_by(title: "Referred a friend discount")
      invoice.invoice_items.create!(
        product: discount,
        quantity: @referred_friends,
        amount: discount.price
      )
      mark_referrals_used
    elsif @referee
      plan_name = @subscription.plan == "XL" ? "XL" : @subscription.plan.downcase
      title = "Referral discount #{plan_name} #{@subscription.duration} month"
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

  def apply_discount_code(invoice)
    code = DiscountCode.find_by(code: @subscription.discount_code.upcase)

    if code&.available?
      if code.percentage_based?
        percent_off = code.discount_percent.clamp(0, 100)
        discount = (invoice.total_amount * percent_off / 100.0).round
        invoice.total_amount -= discount
      elsif code.fixed_amount?
        invoice.total_amount -= (code.discount_cents / 100)
      end

      invoice.total_amount = 0 if invoice.total_amount.negative?
      invoice.used_discount_code = true
      invoice.save!
      code.increment!(:used_count)
    end
  end


  def mark_referrals_used
    @subscription.user.referrals_as_referrer.completed.each(&:used!)
  end
end
