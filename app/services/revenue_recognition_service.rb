class RevenueRecognitionService
  def initialize(invoice)
    @invoice = invoice
  end

  def call
    return unless @invoice.subscription
    return unless @invoice.subscription.start_date
    return unless @invoice.subscription.duration

    # Avoid creating duplicates
    return if @invoice.revenue_recognitions.any?

    create_recognition_records
  end

  private

  def create_recognition_records
    subscription = @invoice.subscription
    monthly_amount = @invoice.total_amount / subscription.duration

    (0...subscription.duration).each do |month_offset|
      period_start = subscription.start_date + month_offset.months
      period_end = period_start.end_of_month

      RevenueRecognition.create!(
        invoice: @invoice,
        subscription: subscription,
        period_start: period_start,
        period_end: period_end,
        period_month: period_start.month,
        period_year: period_start.year,
        recognized_amount: monthly_amount,
        recognition_type: 'subscription'
      )
    end

    Rails.logger.info "Created #{subscription.duration} revenue recognition records for Invoice ##{@invoice.number}"
  end
end
