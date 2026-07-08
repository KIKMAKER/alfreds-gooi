class SyncRevenueRecognitionsJob < ApplicationJob
  queue_as :default

  # Rebuilds an invoice's recognition rows so they always match its current
  # total_amount and issued_date, then recomputes financial_metrics for every
  # month the change touched (old rows' months and new rows' months).
  def perform(invoice_id)
    invoice = Invoice.find_by(id: invoice_id)
    return unless invoice

    old_months = invoice.revenue_recognitions
                        .pluck(:period_year, :period_month).uniq

    result = RevenueRecognitions::Recognize.new(invoice).call(force: true)

    if result.exception?
      Rails.logger.warn "[SyncRevenueRecognitions] Invoice ##{invoice.id}: #{result.reason}"
      return
    end

    (old_months | result.months).each do |year, month|
      CalculateFinancialMetricsJob.perform_now(year, month)
    rescue StandardError => e
      Rails.logger.error "[SyncRevenueRecognitions] Metrics recompute failed for " \
                         "#{year}-#{month}: #{e.message}"
    end
  end
end
