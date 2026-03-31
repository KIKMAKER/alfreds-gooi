# app/services/monthly_invoice_service.rb
class MonthlyInvoiceService
  def initialize(subscription)
    @subscription = subscription
  end

  def call
    return unless @subscription.monthly_invoicing?
    return unless invoice_due?

    generate_monthly_invoice
  end

  # Class method to process all subscriptions that need invoicing
  def self.process_all
    Subscription.where(monthly_invoicing: true, status: :active)
                .where('next_invoice_date <= ?', Date.today)
                .find_each do |subscription|
      new(subscription).call
    end
  end

  private

  def invoice_due?
    return false unless @subscription.next_invoice_date
    @subscription.next_invoice_date <= Date.today
  end

  def generate_monthly_invoice
    invoice = find_or_create_invoice

    if @subscription.Commercial?
      add_commercial_items(invoice)
    else
      add_standard_xl_items(invoice)
    end

    add_starter_kit_installment(invoice)
    invoice.calculate_total

    # Advance next_invoice_date immediately so the job won't re-trigger tomorrow
    @subscription.update!(next_invoice_date: @subscription.next_invoice_date + 4.weeks)

    # Send admin preview — customer email is withheld until admin approves
    notify_or_send_preview(invoice)

    invoice
  end

  def add_commercial_items(invoice)
    monthly_product = find_monthly_collection_product
    raise "monthly_subscription_amount not set on subscription #{@subscription.id} — backfill required" unless @subscription.monthly_subscription_amount
    raise "monthly_volume_amount not set on subscription #{@subscription.id} — backfill required" unless @subscription.monthly_volume_amount

    invoice.invoice_items.create!(
      product: monthly_product,
      quantity: 1,
      amount: @subscription.monthly_subscription_amount
    )

    volume_product = find_volume_product
    invoice.invoice_items.create!(
      product: volume_product,
      quantity: 1,
      amount: @subscription.monthly_volume_amount
    )
  end

  def add_standard_xl_items(invoice)
    raise "monthly_subscription_amount not set on subscription #{@subscription.id} — backfill required" unless @subscription.monthly_subscription_amount

    product = Product.find(@subscription.subscription_product_id)
    invoice.invoice_items.create!(
      product: product,
      quantity: 1,
      amount: @subscription.monthly_subscription_amount
    )
  end

  def find_monthly_collection_product
    product = Product.find_by(id: @subscription.monthly_collection_product_id)
    unless product
      title = case @subscription.duration
              when 12 then "Commercial collection fee (12-month)"
              when 6  then "Commercial collection fee (6-month)"
              when 3  then "Commercial collection fee (3-month)"
              else raise "Unsupported duration for Commercial subscription: #{@subscription.duration}"
              end
      product = Product.find_by(title: title)
      raise "Product not found: #{title}" unless product
      @subscription.update_column(:monthly_collection_product_id, product.id)
    end
    product
  end

  def find_volume_product
    product = Product.find_by(id: @subscription.volume_processing_product_id)
    unless product
      bucket_size = @subscription.bucket_size || 45
      title = "Commercial volume per #{bucket_size}L bucket"
      product = Product.find_by(title: title)
      raise "Product not found: #{title}" unless product
      @subscription.update_column(:volume_processing_product_id, product.id)
    end
    product
  end

  def notify_or_send_preview(invoice)
    user = @subscription.user

    # Check if this user has other subscriptions that still need to add their items today.
    # next_invoice_date has already been advanced 4 weeks, so compare against yesterday.
    other_subs_pending = user.subscriptions
                             .where(monthly_invoicing: true, status: :active)
                             .where.not(id: @subscription.id)
                             .where('next_invoice_date <= ?', Date.today)
                             .count

    if other_subs_pending > 0
      Rails.logger.info "Waiting for #{other_subs_pending} other subscription(s) before sending preview for invoice ##{invoice.id}"
    else
      Rails.logger.info "All subscriptions processed for invoice ##{invoice.id}, sending admin preview"
      InvoiceMailer.with(
        invoice: invoice,
        installment_number: calculate_installment_number
      ).invoice_pending_approval.deliver_now
    end
  end

  def find_or_create_invoice
    user = @subscription.user

    # Look for an unpaid invoice for this user created today.
    # This allows multiple subscriptions to be combined into one invoice.
    existing_invoice = Invoice.joins(:subscription)
                              .where(subscriptions: { user_id: user.id })
                              .where(paid: false)
                              .where('invoices.issued_date >= ?', Time.current.beginning_of_day)
                              .order('invoices.created_at DESC')
                              .first

    if existing_invoice
      Rails.logger.info "Found existing invoice ##{existing_invoice.id} for user #{user.id}, adding subscription #{@subscription.id} to it"
      existing_invoice
    else
      Invoice.create!(
        subscription: @subscription,
        issued_date: Time.current,
        due_date: Time.current + 2.weeks,
        total_amount: 0
        # admin_approved defaults to false — held until admin approves
      )
    end
  end

  def calculate_installment_number
    return 1 unless @subscription.invoices.any?
    @subscription.invoices.count + 1
  end

  def add_starter_kit_installment(invoice)
    return unless @subscription.starter_kit_installment.present?

    bucket_size = @subscription.bucket_size || 45
    kit_title = if @subscription.Commercial?
                  "Commercial Starter Bucket (#{bucket_size}L)"
                else
                  "#{@subscription.plan} Starter Kit"
                end

    kit = Product.find_by(title: kit_title)
    return unless kit

    invoice.invoice_items.create!(
      product: kit,
      quantity: 1,
      amount: @subscription.starter_kit_installment
    )
  end
end
