# app/services/invoice_builder.rb
class InvoiceBuilder
  def initialize(subscription: nil, subscriptions: nil, og: false, is_new: false, referee: nil, referred_friends: 0, auto_approve: false, quotation: nil)
    # Accept either a single subscription or multiple subscriptions
    @subscriptions = subscriptions || [subscription].compact
    raise ArgumentError, "At least one subscription required" if @subscriptions.empty?

    @subscription = @subscriptions.first # Keep for backwards compatibility
    @og = og
    @is_new = is_new
    @referee = referee
    @referred_friends = referred_friends
    @auto_approve = auto_approve
    @quotation = quotation
  end

  def call
    invoice = Invoice.create!(
      subscription: @subscription,
      issued_date: Time.current,
      due_date: Time.current + 2.weeks,
      total_amount: 0,
      admin_approved: @auto_approve
    )

    if @subscription&.once_off?
      add_once_off_collection(invoice)
    else
      @subscriptions.each do |sub|
        if @is_new
          # For quote-driven monthly Commercial, add_subscription_product must run first
          # so it can store starter_kit_installment before add_starter_kit reads it.
          if @quotation.present? && sub.Commercial? && sub.monthly_invoicing?
            add_subscription_product(invoice, sub)
            add_starter_kit(invoice, sub)
          else
            add_starter_kit(invoice, sub)
            add_subscription_product(invoice, sub)
          end
        else
          add_subscription_product(invoice, sub)
          add_monthly_starter_kit_installment(invoice, sub)
        end
      end

      apply_referrals(invoice)
      apply_discount_code(invoice) if @subscription.discount_code
    end

    invoice.calculate_total

    if @auto_approve
      InvoiceMailer.with(invoice: invoice).invoice_created.deliver_now
    else
      InvoiceMailer.with(invoice: invoice).invoice_pending_approval.deliver_now
    end

    invoice
  end

  private

  def add_once_off_collection(invoice)
    product = Product.find_by(title: "Once-off Collection")
    return Rails.logger.warn("Product not found: Once-off Collection") unless product
    invoice.invoice_items.create!(product: product, quantity: 1, amount: product.price)
  end

  def add_starter_kit(invoice, subscription)
    kit_title = if subscription.Commercial?
                  bucket_size = subscription.bucket_size || 45
                  "Commercial Starter Bucket (#{bucket_size}L)"
                else
                  "#{subscription.plan} Starter Kit"
                end

    kit = Product.find_by(title: kit_title)
    raise "Product not found: #{kit_title}" unless kit

    # For commercial subscriptions, add starter kit quantity based on buckets_per_collection
    quantity = subscription.Commercial? ? subscription.buckets_per_collection * (subscription.collections_per_week || 1) : 1

    if subscription.monthly_invoicing? && subscription.duration.present?
      # For the quote-driven monthly path, starter_kit_installment was already set
      # by add_commercial_subscription_from_quote (which ran first). Use that stored value.
      installment_amount = if @quotation.present? && subscription.Commercial? && subscription.starter_kit_installment.present?
                             subscription.starter_kit_installment
                           else
                             total_cost = kit.price * quantity
                             amount = total_cost / subscription.duration
                             subscription.update_column(:starter_kit_installment, amount)
                             amount
                           end

      invoice.invoice_items.create!(product: kit, quantity: 1, amount: installment_amount)
    else
      existing_kit = invoice.invoice_items.find_by(product: kit, amount: kit.price)
      if existing_kit
        existing_kit.update!(quantity: existing_kit.quantity + quantity)
      else
        invoice.invoice_items.create!(product: kit, quantity: quantity, amount: kit.price)
      end
    end
  end

  def add_subscription_product(invoice, subscription)
    if subscription.Commercial?
      @quotation.present? ?
        add_commercial_subscription_from_quote(invoice, subscription) :
        add_commercial_subscription(invoice, subscription)
    elsif subscription.monthly_invoicing?
      add_monthly_subscription(invoice, subscription)
    else
      title = @og ? "#{subscription.plan} #{subscription.duration} month OG subscription"
                  : "#{subscription.plan} #{subscription.duration} month subscription"

      product = Product.find_by(title: title)
      raise "Product not found: #{title}" unless product

      subscription.update_column(:subscription_product_id, product.id)
      invoice.invoice_items.create!(product: product, quantity: 1, amount: product.price)
    end
  end

  # Quote-driven path: use the agreed quote amounts and map products through
  # their invoice_product_id rather than re-deriving from the rate card.
  def add_commercial_subscription_from_quote(invoice, subscription)
    billable = @quotation.billable_items

    starter_items   = billable.select { |i| i.product.title.match?(/starter/i) }
    recurring_items = billable.reject { |i| i.product.title.match?(/starter/i) }

    # Identify the collection-fee and volume invoice products for storing on subscription
    monthly_product = nil
    volume_product  = nil
    recurring_items.each do |item|
      inv_product = item.product.effective_invoice_product
      if inv_product.title.match?(/collection fee/i)
        monthly_product = inv_product
      elsif inv_product.title.match?(/volume per/i)
        volume_product = inv_product
      end
    end

    if subscription.monthly_invoicing?
      add_commercial_from_quote_monthly(invoice, subscription, recurring_items, starter_items, monthly_product, volume_product)
    else
      add_commercial_from_quote_upfront(invoice, subscription, recurring_items, monthly_product, volume_product)
    end
  end

  def add_commercial_from_quote_upfront(invoice, subscription, recurring_items, monthly_product, volume_product)
    # Store product FKs on subscription so MonthlyInvoiceService can find them if needed
    subscription.update_columns(
      monthly_collection_product_id: monthly_product&.id,
      volume_processing_product_id:  volume_product&.id
    )

    recurring_items.each do |item|
      invoice.invoice_items.create!(
        product:  item.product.effective_invoice_product,
        quantity: item.quantity.to_f,
        amount:   item.amount.to_f
      )
    end
  end

  def add_commercial_from_quote_monthly(invoice, subscription, recurring_items, starter_items, monthly_product, volume_product)
    duration = subscription.duration.to_f

    collection_total = recurring_items
      .select { |i| i.product.effective_invoice_product == monthly_product }
      .sum    { |i| i.amount.to_f * i.quantity.to_f }

    volume_total = recurring_items
      .select { |i| i.product.effective_invoice_product == volume_product }
      .sum    { |i| i.amount.to_f * i.quantity.to_f }

    starter_total = starter_items.sum { |i| i.amount.to_f * i.quantity.to_f }

    monthly_collection = (collection_total / duration).round(2)
    monthly_volume     = (volume_total     / duration).round(2)
    monthly_starter    = (starter_total    / duration).round(2)
    contract_total     = collection_total + volume_total + starter_total

    if @is_new
      subscription.update!(
        monthly_subscription_amount:    monthly_collection,
        monthly_volume_amount:          monthly_volume,
        starter_kit_installment:        monthly_starter,
        contract_total:                 contract_total.round(2),
        next_invoice_date:              Date.today + 4.weeks,
        monthly_collection_product_id:  monthly_product&.id,
        volume_processing_product_id:   volume_product&.id
      )
    end

    invoice.invoice_items.create!(product: monthly_product, quantity: 1, amount: subscription.monthly_subscription_amount) if monthly_product
    invoice.invoice_items.create!(product: volume_product,  quantity: 1, amount: subscription.monthly_volume_amount)       if volume_product
  end

  # Existing rate-card path — untouched, still used for non-quote commercial subscriptions.
  def add_commercial_subscription(invoice, subscription)
    monthly_title = case subscription.duration
                    when 12 then "Commercial collection fee (12-month)"
                    when 6  then "Commercial collection fee (6-month)"
                    when 3  then "Commercial collection fee (3-month)"
                    else raise "Unsupported duration for Commercial subscription: #{subscription.duration}"
                    end

    monthly_product = Product.find_by(title: monthly_title)
    raise "Product not found: #{monthly_title}" unless monthly_product

    bucket_size  = subscription.bucket_size || 45
    volume_title = "Commercial volume per #{bucket_size}L bucket"

    volume_product = Product.invoice_eligible.find_by(title: volume_title)
    raise "Product not found (or not invoice_eligible): #{volume_title}" unless volume_product

    subscription.update_columns(
      monthly_collection_product_id: monthly_product.id,
      volume_processing_product_id:  volume_product.id
    )

    collections_per_week = subscription.collections_per_week || 1

    if subscription.monthly_invoicing?
      visits_per_month = (52.0 / 12.0 * collections_per_week).round
      monthly_volume   = subscription.buckets_per_collection * volume_product.price * visits_per_month

      if @is_new
        monthly_starter = subscription.starter_kit_installment.to_f
        contract_total  = (monthly_product.price + monthly_volume + monthly_starter) * subscription.duration
        subscription.update!(
          contract_total:               contract_total,
          next_invoice_date:            Date.today + 4.weeks,
          monthly_volume_amount:        monthly_volume,
          monthly_subscription_amount:  monthly_product.price
        )
      end

      invoice.invoice_items.create!(product: monthly_product, quantity: 1, amount: monthly_product.price)
      invoice.invoice_items.create!(product: volume_product,  quantity: 1, amount: monthly_volume)
    else
      total_visits    = (52.0 / 12.0 * collections_per_week).round * subscription.duration
      volume_per_visit = subscription.buckets_per_collection * volume_product.price

      invoice.invoice_items.create!(
        product:  monthly_product,
        quantity: subscription.duration * collections_per_week,
        amount:   monthly_product.price
      )
      invoice.invoice_items.create!(
        product:  volume_product,
        quantity: total_visits,
        amount:   volume_per_visit
      )
    end
  end

  def add_monthly_subscription(invoice, subscription)
    title   = "#{subscription.plan} #{subscription.duration} month subscription"
    product = Product.find_by(title: title)
    raise "Product not found: #{title}" unless product

    monthly_amount = product.price.to_f / subscription.duration

    if @is_new
      monthly_starter = subscription.starter_kit_installment.to_f
      subscription.update!(
        subscription_product_id:      product.id,
        monthly_subscription_amount:  monthly_amount,
        next_invoice_date:            Date.today + 4.weeks,
        contract_total:               (monthly_amount + monthly_starter) * subscription.duration
      )
    end

    invoice.invoice_items.create!(
      product:  product,
      quantity: 1,
      amount:   subscription.monthly_subscription_amount || monthly_amount
    )
  end

  def apply_referrals(invoice)
    if @referred_friends&.positive?
      discount = Product.find_by(title: "Referred a friend discount (R50)")
      invoice.invoice_items.create!(product: discount, quantity: @referred_friends, amount: discount.price)
      mark_referrals_used
    elsif @referee && @referee != @subscription.user
      plan_name = @subscription.plan == "XL" ? "XL" : @subscription.plan.downcase
      title     = "Referral discount #{plan_name} #{@subscription.duration} month"
      discount  = Product.find_by(title: title)
      invoice.invoice_items.create!(product: discount, quantity: 1, amount: discount.price)

      unless @subscription.user.referrals_as_referee.exists?
        Referral.create!(
          subscription: @subscription,
          referee:      @subscription.user,
          referrer:     @referee,
          status:       :pending
        )
      end
    end
  end

  def apply_discount_code(invoice)
    code = DiscountCode.find_by(code: @subscription.discount_code.upcase)

    if code&.available?
      return if code.used_by?(@subscription.user)

      subtotal = invoice.invoice_items.sum { |item| item.amount * item.quantity }

      discount_amount = if code.percentage_based?
                          (subtotal * code.discount_percent.clamp(0, 100) / 100.0).round(2)
                        elsif code.fixed_amount?
                          (code.discount_cents / 100.0).round(2)
                        else
                          0
                        end

      discount_amount = subtotal if discount_amount > subtotal

      if discount_amount > 0
        invoice.invoice_discount_codes.create!(discount_code: code, discount_amount: discount_amount)
        invoice.used_discount_code = true
        invoice.save!
        code.increment!(:used_count)
      end
    end
  end

  def mark_referrals_used
    @subscription.user.referrals_as_referrer.completed.each(&:used!)
  end

  def add_monthly_starter_kit_installment(invoice, subscription)
    return unless subscription.monthly_invoicing?
    return unless subscription.starter_kit_installment.present?

    kit_title = if subscription.Commercial?
                  bucket_size = subscription.bucket_size || 45
                  "Commercial Starter Bucket (#{bucket_size}L)"
                else
                  "#{subscription.plan} Starter Kit"
                end

    kit = Product.find_by(title: kit_title)
    return unless kit

    invoice.invoice_items.create!(product: kit, quantity: 1, amount: subscription.starter_kit_installment)
  end
end
