class Subscriptions::UsageTrueUp
  Result = Struct.new(:success, :error, keyword_init: true)
  Review = Struct.new(:period_start, :actual_litres, :contracted_litres, :excess_litres, :catch_up_amount, keyword_init: true)

  def initialize(subscription)
    @subscription = subscription
  end

  def review
    period_start   = @subscription.last_usage_review_date || @subscription.start_date&.to_date
    actual_litres  = combined_subscriptions.sum { |s| s.total_litres_between(period_start, Date.today) }
    contracted_litres = combined_subscriptions.sum do |s|
      period_collections = s.collections.where(skip: false, date: period_start..Date.today).count
      s.allowed_litres_per_collection * period_collections
    end
    excess_litres = [actual_litres - contracted_litres, 0].max

    Review.new(
      period_start:       period_start,
      actual_litres:      actual_litres,
      contracted_litres:  contracted_litres,
      excess_litres:       excess_litres,
      catch_up_amount:    (excess_litres * contracted_rate_per_litre).round(2)
    )
  end

  def create_invoice!(new_buckets_per_collection:)
    return Result.new(success: false, error: "Usage true-up isn't available on a satellite subscription — use the primary.") if @subscription.satellite?
    return Result.new(success: false, error: "Enter a new buckets-per-collection value.") if new_buckets_per_collection.blank?

    new_buckets_per_collection = new_buckets_per_collection.to_i
    unless (1..20).cover?(new_buckets_per_collection)
      return Result.new(success: false, error: "Buckets per collection must be between 1 and 20.")
    end

    result = nil
    ActiveRecord::Base.transaction do
      r = review
      rate = contracted_rate_per_litre

      invoice = Invoice.create!(
        subscription:   @subscription,
        issued_date:    Time.current,
        due_date:       Time.current + 2.weeks,
        total_amount:   0,
        admin_approved: false
      )

      added_line = false

      if r.catch_up_amount > 0
        invoice.invoice_items.create!(
          product:  @subscription.volume_processing_product,
          quantity: 1,
          amount:   r.catch_up_amount
        )
        added_line = true
      end

      remaining = @subscription.remaining_collections.to_i
      bucket_delta = new_buckets_per_collection - @subscription.buckets_per_collection

      if !@subscription.monthly_invoicing? && remaining.positive? && bucket_delta != 0
        remaining_term_amount = (remaining * bucket_delta * @subscription.bucket_size * rate).round(2)
        if remaining_term_amount != 0
          invoice.invoice_items.create!(
            product:  @subscription.volume_processing_product,
            quantity: 1,
            amount:   remaining_term_amount
          )
          added_line = true
        end
      end

      unless added_line
        result = Result.new(success: false, error: "No charge needed — usage and plan are already in line.")
        raise ActiveRecord::Rollback
      end

      @subscription.update!(buckets_per_collection: new_buckets_per_collection, last_usage_review_date: Date.today)

      if @subscription.monthly_invoicing?
        visits_per_month = (52.0 / 12.0 * (@subscription.collections_per_week || 1)).round
        new_monthly_volume = (new_buckets_per_collection * @subscription.bucket_size * visits_per_month * rate).round(2)
        new_contract_total = (@subscription.monthly_subscription_amount.to_f + new_monthly_volume + @subscription.starter_kit_installment.to_f) * @subscription.duration

        @subscription.update!(monthly_volume_amount: new_monthly_volume, contract_total: new_contract_total.round(2))
      end

      invoice.calculate_total
      InvoiceMailer.with(invoice: invoice).invoice_pending_approval.deliver_now
      result = Result.new(success: true, error: nil)
    end

    result
  rescue => e
    Result.new(success: false, error: e.message)
  end

  private

  def combined_subscriptions
    @combined_subscriptions ||= [@subscription] + @subscription.satellite_subscriptions
  end

  # "R per litre this specific customer agreed to." Deliberately not
  # `volume_processing_product.price` — that's today's catalog price and can
  # drift from what a quote-driven customer actually signed. Monthly subs pin
  # their rate in `monthly_volume_amount` at signup (invoice_builder.rb) and
  # it's never recalculated from the catalog afterwards, so it's a safe
  # source; upfront subs have no such cache, so derive it from what the
  # original invoice actually billed for volume.
  def contracted_rate_per_litre
    if @subscription.monthly_invoicing?
      visits_per_month = (52.0 / 12.0 * (@subscription.collections_per_week || 1)).round
      @subscription.monthly_volume_amount.to_f / (@subscription.buckets_per_collection * @subscription.bucket_size * visits_per_month)
    else
      original_invoice = @subscription.invoices.order(:created_at).first
      volume_item = original_invoice&.invoice_items&.find_by(product: @subscription.volume_processing_product)

      total_volume_amount = if volume_item
                              volume_item.amount.to_f * volume_item.quantity.to_f
                            else
                              @subscription.volume_processing_product.price.to_f * @subscription.buckets_per_collection
                            end

      total_contracted_visits = (@subscription.duration * 4.2).ceil * (@subscription.collections_per_week || 1)
      total_volume_amount / (@subscription.buckets_per_collection * @subscription.bucket_size * total_contracted_visits)
    end
  end
end
