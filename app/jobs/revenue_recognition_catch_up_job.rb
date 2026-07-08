class RevenueRecognitionCatchUpJob < ApplicationJob
  queue_as :default

  # Nightly safety net: the invoice-creation hook should leave no invoice
  # without recognition rows, so finding any here means something slipped
  # through — backfill them and shout in the logs so the table never
  # silently decays again.
  def perform
    missing_count = Invoice.where.missing(:revenue_recognitions).count
    return if missing_count.zero?

    Rails.logger.error "[RevenueRecognitionCatchUp] #{missing_count} invoice(s) have no " \
                       "recognition rows — the invoice-creation hook missed them. Backfilling."

    results = RevenueRecognitions::Backfill.new(dry_run: false).call

    results.select(&:exception?).each do |result|
      Rails.logger.error "[RevenueRecognitionCatchUp] Invoice ##{result.invoice.id} " \
                         "skipped: #{result.reason}"
    end

    RevenueRecognitions::Backfill.affected_months(results).each do |year, month|
      CalculateFinancialMetricsJob.perform_now(year, month)
    rescue StandardError => e
      Rails.logger.error "[RevenueRecognitionCatchUp] Metrics recompute failed for " \
                         "#{year}-#{month}: #{e.message}"
    end
  end
end
