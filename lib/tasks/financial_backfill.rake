namespace :financial do
  desc "Backfill revenue recognitions for all paid invoices"
  task backfill_revenue_recognitions: :environment do
    puts "Starting revenue recognition backfill..."

    paid_invoices = Invoice.where(paid: true).includes(:subscription)
    total = paid_invoices.count
    processed = 0
    skipped = 0
    created = 0

    paid_invoices.find_each do |invoice|
      processed += 1

      unless invoice.subscription
        puts "  [#{processed}/#{total}] Skipping invoice ##{invoice.number || invoice.id} - no subscription"
        skipped += 1
        next
      end

      # Check if already has revenue recognitions
      if invoice.revenue_recognitions.any?
        puts "  [#{processed}/#{total}] Skipping invoice ##{invoice.number || invoice.id} - already has #{invoice.revenue_recognitions.count} recognitions"
        skipped += 1
        next
      end

      begin
        service = RevenueRecognitionService.new(invoice)
        service.call

        recognition_count = invoice.revenue_recognitions.count
        created += recognition_count
        puts "  [#{processed}/#{total}] Created #{recognition_count} revenue recognitions for invoice ##{invoice.number || invoice.id}"
      rescue => e
        puts "  [#{processed}/#{total}] ERROR processing invoice ##{invoice.number || invoice.id}: #{e.message}"
        skipped += 1
      end
    end

    puts "\nBackfill complete!"
    puts "  Total invoices: #{total}"
    puts "  Processed: #{processed}"
    puts "  Skipped: #{skipped}"
    puts "  Revenue recognitions created: #{created}"
  end

  desc "Recalculate all historical financial metrics"
  task recalculate_metrics: :environment do
    puts "Starting financial metrics recalculation..."

    # Find the earliest transaction date from either expenses or invoices
    earliest_expense = Expense.minimum(:transaction_date)
    earliest_invoice = Invoice.minimum(:issued_date)

    start_date = [earliest_expense, earliest_invoice].compact.min || 1.year.ago
    end_date = Date.current

    puts "Calculating metrics from #{start_date.strftime('%B %Y')} to #{end_date.strftime('%B %Y')}"

    # Get all month starts in the range
    month_starts = []
    current = start_date.beginning_of_month
    while current <= end_date
      month_starts << current
      current = current.next_month
    end

    total_months = month_starts.count
    processed = 0

    month_starts.each do |month_start|
      processed += 1
      year = month_start.year
      month = month_start.month

      begin
        calculator = FinancialMetricsCalculator.new(year, month)
        calculator.calculate

        metric = FinancialMetric.find_by(year: year, month: month)
        puts "  [#{processed}/#{total_months}] #{month_start.strftime('%B %Y')}: Revenue: R#{metric.recognized_revenue.to_i}, Expenses: R#{metric.total_expenses.to_i}, Profit: R#{metric.net_profit.to_i}"
      rescue => e
        puts "  [#{processed}/#{total_months}] ERROR calculating #{month_start.strftime('%B %Y')}: #{e.message}"
      end
    end

    puts "\nRecalculation complete!"
    puts "  Months processed: #{total_months}"
    puts "  Metrics records: #{FinancialMetric.count}"
  end

  desc "Backfill all financial data (revenue recognitions + metrics)"
  task backfill_all: :environment do
    puts "=" * 80
    puts "FINANCIAL DATA BACKFILL"
    puts "=" * 80
    puts ""

    Rake::Task['financial:backfill_revenue_recognitions'].invoke
    puts ""
    puts "=" * 80
    puts ""
    Rake::Task['financial:recalculate_metrics'].invoke

    puts ""
    puts "=" * 80
    puts "ALL DONE! Your financial dashboard is ready to use."
    puts "=" * 80
  end
end
