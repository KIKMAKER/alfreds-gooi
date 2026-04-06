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
      # admin_approved defaults to false — held until admin clicks approve
    )

    if @subscription&.once_off?
      add_once_off_collection(invoice)
    else
      # Add items for each subscription
      @subscriptions.each do |sub|
        add_starter_kit(invoice, sub) if @is_new
        add_subscription_product(invoice, sub)
        # Add starter kit installment for subsequent monthly invoices
        add_monthly_starter_kit_installment(invoice, sub) unless @is_new
      end

      apply_referrals(invoice)
      apply_discount_code(invoice) if @subscription.discount_code
    end

    invoice.calculate_total # Calculate total AFTER adding all items including discounts

    InvoiceMailer.with(invoice: invoice).invoice_pending_approval.deliver_now

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
    quantity = subscription.Commercial? ? subscription.buckets_per_collection : 1

    # For monthly invoicing, split the cost into installments
    if subscription.monthly_invoicing? && subscription.duration.present?
      # Calculate installment amount (total cost / duration)
      total_cost = kit.price * quantity
      installment_amount = total_cost / subscription.duration

      # Add as monthly installment (quantity = 1 per month)
      invoice.invoice_items.create!(
        product: kit,
        quantity: 1,
        amount: installment_amount
      )

      # Store the installment amount on subscription for future invoices
      subscription.update_column(:starter_kit_installment, installment_amount)
    else
      # Standard behavior: charge full amount upfront
      # Find existing kit item to consolidate
      existing_kit = invoice.invoice_items.find_by(
        product: kit,
        amount: kit.price
      )

      if existing_kit
        # Add to existing quantity
        existing_kit.update!(quantity: existing_kit.quantity + quantity)
      else
        # Create new invoice item
        invoice.invoice_items.create!(product: kit, quantity: quantity, amount: kit.price)
      end
    end
  end

  def add_subscription_product(invoice, subscription)
    if subscription.Commercial?
      add_commercial_subscription(invoice, subscription)
    elsif subscription.monthly_invoicing?
      add_monthly_subscription(invoice, subscription)
    else
      title = if @og
                "#{subscription.plan} #{subscription.duration} month OG subscription"
              else
                "#{subscription.plan} #{subscription.duration} month subscription"
              end

      product = Product.find_by(title: title)
      raise "Product not found: #{title}" unless product

      # Store product_id on subscription for future reference
      subscription.update_column(:subscription_product_id, product.id)

      invoice.invoice_items.create!(product: product, quantity: 1, amount: product.price)
    end
  end

  def add_monthly_subscription(invoice, subscription)
    title = "#{subscription.plan} #{subscription.duration} month subscription"
    product = Product.find_by(title: title)
    raise "Product not found: #{title}" unless product

    monthly_amount = product.price.to_f / subscription.duration

    if @is_new
      monthly_starter = subscription.starter_kit_installment.to_f
      subscription.update!(
        subscription_product_id: product.id,
        monthly_subscription_amount: monthly_amount,
        next_invoice_date: Date.today + 4.weeks,
        contract_total: (monthly_amount + monthly_starter) * subscription.duration
      )
    end

    invoice.invoice_items.create!(
      product: product,
      quantity: 1,
      amount: subscription.monthly_subscription_amount || monthly_amount
    )
  end

  def add_commercial_subscription(invoice, subscription)
    # Collection fee: duration-specific flat monthly rate
    monthly_title = case subscription.duration
                    when 12 then "Commercial collection fee (12-month)"
                    when 6  then "Commercial collection fee (6-month)"
                    when 3  then "Commercial collection fee (3-month)"
                    else raise "Unsupported duration for Commercial subscription: #{subscription.duration}"
                    end

    monthly_product = Product.find_by(title: monthly_title)
    raise "Product not found: #{monthly_title}" unless monthly_product

    # Volume: per bucket per visit, rate is R1.70/L regardless of duration
    bucket_size = subscription.bucket_size || 45
    volume_title = "Commercial volume per #{bucket_size}L bucket"

    volume_product = Product.find_by(title: volume_title)
    raise "Product not found: #{volume_title}" unless volume_product

    # Store product_ids on subscription for future monthly invoicing
    subscription.update_columns(
      monthly_collection_product_id: monthly_product.id,
      volume_processing_product_id: volume_product.id
    )

    collections_per_week = subscription.collections_per_week || 1

    if subscription.monthly_invoicing?
      # Monthly volume = (buckets × total-contract-cost-per-bucket) / duration
      # e.g. 3 buckets × R540 (6-month total per bucket) / 6 months = R270/month
      monthly_volume = (subscription.buckets_per_collection * volume_product.price) / subscription.duration

      if @is_new
        # Only set contract_total and lock in monthly amounts at inception
        monthly_starter = subscription.starter_kit_installment.to_f
        contract_total = (monthly_product.price + monthly_volume + monthly_starter) * subscription.duration
        subscription.update!(
          contract_total: contract_total,
          next_invoice_date: Date.today + 4.weeks,
          monthly_volume_amount: monthly_volume,
          monthly_subscription_amount: monthly_product.price
        )
      end

      invoice.invoice_items.create!(
        product: monthly_product,
        quantity: 1,
        amount: monthly_product.price
      )

      invoice.invoice_items.create!(
        product: volume_product,
        quantity: 1,
        amount: monthly_volume
      )
    else
      # Upfront contract billing: invoice full duration in one go
      total_visits = (52.0 / 12.0 * collections_per_week).round * subscription.duration
      volume_per_visit = subscription.buckets_per_collection * volume_product.price

      invoice.invoice_items.create!(
        product: monthly_product,
        quantity: subscription.duration,
        amount: monthly_product.price
      )

      invoice.invoice_items.create!(
        product: volume_product,
        quantity: total_visits,
        amount: volume_per_visit
      )
    end
  end

  def apply_referrals(invoice)
    if @referred_friends&.positive?
      discount = Product.find_by(title: "Referred a friend discount (R50)")
      invoice.invoice_items.create!(
        product: discount,
        quantity: @referred_friends,
        amount: discount.price
      )
      mark_referrals_used
    elsif @referee && @referee != @subscription.user
      plan_name = @subscription.plan == "XL" ? "XL" : @subscription.plan.downcase
      title = "Referral discount #{plan_name} #{@subscription.duration} month"
      discount = Product.find_by(title: title)
      invoice.invoice_items.create!(product: discount, quantity: 1, amount: discount.price)

      unless @subscription.user.referrals_as_referee.exists?
        Referral.create!(
          subscription: @subscription,
          referee: @subscription.user,
          referrer: @referee,
          status: :pending
        )
      end
    end

  end

  def apply_discount_code(invoice)
    code = DiscountCode.find_by(code: @subscription.discount_code.upcase)

    if code&.available?
      # Validate 3-month-only restriction
      if code.three_month_only? && @subscription.duration != 3
        Rails.logger.info "Discount code #{code.code} is only valid for 3-month subscriptions (attempted on #{@subscription.duration}-month)"
        return
      end

      # Calculate the pre-discount subtotal
      subtotal = invoice.invoice_items.sum { |item| item.amount * item.quantity }

      discount_amount = if code.percentage_based?
        percent_off = code.discount_percent.clamp(0, 100)
        (subtotal * percent_off / 100.0).round(2)
      elsif code.fixed_amount?
        (code.discount_cents / 100.0).round(2)
      else
        0
      end

      # Don't apply discount if it would make total negative
      discount_amount = subtotal if discount_amount > subtotal

      if discount_amount > 0
        # Create the association between invoice and discount code
        invoice.invoice_discount_codes.create!(
          discount_code: code,
          discount_amount: discount_amount
        )

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

    # Find the starter kit product to link to
    kit_title = if subscription.Commercial?
                  bucket_size = subscription.bucket_size || 45
                  "Commercial Starter Bucket (#{bucket_size}L)"
                else
                  "#{subscription.plan} Starter Kit"
                end

    kit = Product.find_by(title: kit_title)
    return unless kit

    invoice.invoice_items.create!(
      product: kit,
      quantity: 1,
      amount: subscription.starter_kit_installment
    )
  end
end
