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
    # Calculate which month this is (1st, 2nd, 3rd, etc.)
    installment_number = calculate_installment_number

    # Calculate the collections for this month's invoice
    # Weekly collections, so roughly 4-5 collections per month
    collections_per_month = (52.0 / 12.0).round

    # Get the bucket configuration
    bucket_size = @subscription.bucket_size || 45
    buckets_per_collection = @subscription.buckets_per_collection
    collections_per_week = @subscription.collections_per_week || 1

    # Check if user already has an unpaid invoice from this invoicing cycle
    # This allows combining multiple subscriptions into one invoice
    invoice = find_or_create_invoice

    # Add monthly collection fee
    monthly_title = case @subscription.duration
                    when 12
                      "Commercial weekly collection per month (12-month rate)"
                    when 6
                      "Commercial weekly collection per month (6-month rate)"
                    when 3
                      "Commercial weekly collection per month (3-month rate)"
                    else
                      raise "Unsupported duration for Commercial subscription: #{@subscription.duration}"
                    end

    monthly_product = Product.find_by(title: monthly_title)
    raise "Product not found: #{monthly_title}" unless monthly_product

    invoice.invoice_items.create!(
      product: monthly_product,
      quantity: 1 * collections_per_week, # One month × collections per week
      amount: monthly_product.price
    )

    # Add volume processing charge
    volume_title = case @subscription.duration.to_i
                   when 12
                     "Volume Processing per #{bucket_size}L (12-month rate)"
                   when 6
                     "Volume Processing per #{bucket_size}L (Premium 6-month rate)"
                   when 3
                     "Volume Processing per #{bucket_size}L (3-month rate)"
                   else
                     raise "Unsupported duration for Commercial subscription: #{@subscription.duration}"
                   end

    volume_product = Product.find_by(title: volume_title)
    raise "Product not found: #{volume_title}" unless volume_product

    volume_amount = buckets_per_collection * volume_product.price

    invoice.invoice_items.create!(
      product: volume_product,
      quantity: collections_per_month * collections_per_week,
      amount: volume_amount
    )

    # Add starter kit installment if applicable
    add_starter_kit_installment(invoice)

    # Calculate and save total
    invoice.calculate_total

    # Update subscription's next invoice date (add ~4 weeks)
    @subscription.update!(
      next_invoice_date: @subscription.next_invoice_date + 4.weeks
    )

    # Check if there are any OTHER subscriptions for this user that still need invoicing today
    user = @subscription.user
    other_subs_needing_invoice = user.subscriptions
                                     .where(monthly_invoicing: true, status: :active)
                                     .where.not(id: @subscription.id)
                                     .where('next_invoice_date <= ?', Date.today)
                                     .count

    if other_subs_needing_invoice > 0
      # Don't send email yet, other subscriptions still need to add their items
      Rails.logger.info "Added subscription #{@subscription.id} to invoice ##{invoice.id}, but #{other_subs_needing_invoice} other subscription(s) still need processing"
    else
      # This is the last subscription to be processed, send the email now
      Rails.logger.info "All subscriptions processed for invoice ##{invoice.id}, sending email"

      # Send invoice email to customer
      InvoiceMailer.with(invoice: invoice).invoice_created.deliver_now

      # Send admin notification
      InvoiceMailer.with(
        invoice: invoice,
        installment_number: installment_number
      ).invoice_created_alert.deliver_now
    end

    invoice
  end

  def find_or_create_invoice
    user = @subscription.user

    # Look for an unpaid invoice for this user created in the last 24 hours
    # This allows multiple subscriptions to be combined into one invoice
    existing_invoice = Invoice.joins(:subscription)
                              .where(subscriptions: { user_id: user.id })
                              .where(paid: false)
                              .where('invoices.issued_date >= ?', Time.current.beginning_of_day)
                              .order('invoices.created_at DESC')
                              .first

    if existing_invoice
      Rails.logger.info "Found existing unpaid invoice ##{existing_invoice.id} for user #{user.id}, adding subscription #{@subscription.id} to it"
      existing_invoice
    else
      # Create new invoice
      Invoice.create!(
        subscription: @subscription,
        issued_date: Time.current,
        due_date: Time.current + 2.weeks,
        total_amount: 0
      )
    end
  end

  def calculate_installment_number
    return 1 unless @subscription.invoices.any?

    # Count how many invoices have been created so far
    @subscription.invoices.count + 1
  end

  def add_starter_kit_installment(invoice)
    return unless @subscription.starter_kit_installment.present?

    # Find the starter kit product to link to
    bucket_size = @subscription.bucket_size || 45
    kit_title = "Commercial Starter Buckets (#{bucket_size}L)"

    kit = Product.find_by(title: kit_title)
    return unless kit

    invoice.invoice_items.create!(
      product: kit,
      quantity: 1,
      amount: @subscription.starter_kit_installment
    )
  end
end
