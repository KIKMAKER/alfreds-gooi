class Subscriptions::ChangePlan
  Result = Struct.new(:success, :error, keyword_init: true)

  def initialize(subscription, new_plan)
    @subscription = subscription
    @new_plan     = new_plan
  end

  def call
    return Result.new(success: false, error: "No plan change needed.") if @new_plan == @subscription.plan
    return Result.new(success: false, error: "Plan changes only supported between Standard and XL.") unless changeable?

    old_plan    = @subscription.plan  # capture before update!
    new_product = Product.find_by(title: "#{@new_plan} #{@subscription.duration} month subscription")
    return Result.new(success: false, error: "No #{@new_plan} #{@subscription.duration}-month product found.") unless new_product

    old_product = Product.find_by(id: @subscription.subscription_product_id)
    invoice     = @subscription.invoices.order(:created_at).first

    ActiveRecord::Base.transaction do
      @subscription.update!(plan: @new_plan, subscription_product_id: new_product.id)

      if invoice && !invoice.paid?
        update_invoice_in_place(invoice, old_product, new_product, old_plan)
      elsif invoice&.paid?
        create_adjustment_invoice(old_product, new_product, old_plan)
      end
    end

    SubscriptionMailer.with(subscription: @subscription).plan_changed.deliver_later
    Result.new(success: true, error: nil)
  rescue => e
    Result.new(success: false, error: e.message)
  end

  private

  def changeable?
    %w[Standard XL].include?(@subscription.plan) && %w[Standard XL].include?(@new_plan)
  end

  def update_invoice_in_place(invoice, old_product, new_product, old_plan)
    if old_product && (item = invoice.invoice_items.find_by(product: old_product))
      item.update!(product: new_product, amount: new_product.price)
    end

    if @subscription.is_new_customer?
      old_kit = Product.find_by(title: "#{old_plan} Starter Kit")
      new_kit = Product.find_by(title: "#{@new_plan} Starter Kit")
      if old_kit && new_kit && (kit_item = invoice.invoice_items.find_by(product: old_kit))
        kit_item.update!(product: new_kit, amount: new_kit.price)
      end
    end

    invoice.calculate_total
  end

  def create_adjustment_invoice(old_product, new_product, old_plan)
    plan_diff = new_product.price - (old_product&.price || 0)

    kit_diff = if @subscription.is_new_customer?
                 old_kit = Product.find_by(title: "#{old_plan} Starter Kit")
                 new_kit = Product.find_by(title: "#{@new_plan} Starter Kit")
                 new_kit && old_kit ? new_kit.price - old_kit.price : 0
               else
                 0
               end

    return if plan_diff == 0 && kit_diff == 0

    adj = Invoice.create!(
      subscription:   @subscription,
      issued_date:    Time.current,
      due_date:       Time.current + 2.weeks,
      total_amount:   0,
      admin_approved: false
    )

    adj.invoice_items.create!(product: new_product, quantity: 1, amount: plan_diff) if plan_diff != 0

    if kit_diff != 0 && (new_kit = Product.find_by(title: "#{@new_plan} Starter Kit"))
      adj.invoice_items.create!(product: new_kit, quantity: 1, amount: kit_diff)
    end

    adj.calculate_total
    InvoiceMailer.with(invoice: adj).invoice_pending_approval.deliver_now
  end
end
