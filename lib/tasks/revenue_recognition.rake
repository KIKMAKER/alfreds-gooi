namespace :revenue_recognition do
  RR_MONEY = ->(v) { format("R%.2f", v.to_f) }

  RR_INVOICE_LABEL = lambda do |invoice|
    sub = invoice.subscription
    context = if invoice.order_id.present?
                "order ##{invoice.order_id}"
              elsif sub
                extras = []
                extras << "monthly" if sub.monthly_invoicing?
                extras << "#{sub.duration}mo" if sub.duration
                "#{sub.plan}#{extras.any? ? " (#{extras.join(', ')})" : ''}"
              elsif invoice.legacy_subscription_id.present?
                "legacy ##{invoice.legacy_subscription_id}"
              else
                "orphan"
              end
    paid = invoice.paid? ? "paid" : "UNPAID"
    "##{invoice.number || invoice.id}  #{invoice.issued_date}  #{RR_MONEY.call(invoice.total_amount)}  #{context}  #{paid}"
  end

  RR_PLAN_LINE = lambda do |rows|
    rows.map { |r| "#{r.period_start.strftime('%Y-%m')} #{RR_MONEY.call(r.recognized_amount)} #{r.recognition_type}" }
        .join(" | ")
  end

  RR_MONTHLY_TABLE = lambda do
    months = 11.downto(0).map { |i| Date.today.beginning_of_month << i }
    puts format("  %-9s %14s %14s %9s", "Month", "Invoiced", "Recognized", "Ratio")
    months.each do |m|
      invoiced = Invoice.where(issued_date: m..m.end_of_month).sum(:total_amount).to_f
      recognized = RevenueRecognition.for_month(m.year, m.month).sum(:recognized_amount).to_f
      ratio = invoiced.zero? ? "-" : format("%.0f%%", recognized / invoiced * 100)
      puts format("  %-9s %14s %14s %9s", m.strftime("%Y-%m"), RR_MONEY.call(invoiced), RR_MONEY.call(recognized), ratio)
    end
    puts "  (Invoiced = by issue month; Recognized = by service month — they differ by design where invoices spread across months.)"
  end

  desc "Read-only report: recognition coverage, uncovered-invoice distribution, spot-checks"
  task investigate: :environment do
    puts "=" * 80
    puts "REVENUE RECOGNITION — INVESTIGATION (read-only)"
    puts "=" * 80

    total    = Invoice.count
    paid     = Invoice.where(paid: true).count
    covered  = Invoice.joins(:revenue_recognitions).distinct.count
    missing  = Invoice.where.missing(:revenue_recognitions)

    puts "\nCoverage: #{covered}/#{total} invoices have recognition rows (#{paid} are paid)."
    puts "Uncovered: #{missing.count} invoices, totalling #{RR_MONEY.call(missing.sum(:total_amount))}"

    by_plan = missing.left_joins(:subscription).group("subscriptions.plan").count
                     .transform_keys { |k| k.nil? ? "(no subscription)" : k }
    by_duration = missing.left_joins(:subscription).group("subscriptions.duration").count
    by_monthly  = missing.left_joins(:subscription).group("subscriptions.monthly_invoicing").count
    puts "\nUncovered by plan:       #{by_plan.inspect}"
    puts "Uncovered by duration:   #{by_duration.inspect}"
    puts "Uncovered by monthly:    #{by_monthly.inspect}"
    puts "Uncovered by paid:       #{missing.group(:paid).count.inspect}"
    puts "Uncovered with order_id: #{missing.where.not(order_id: nil).count}"
    puts "Uncovered legacy-only:   #{missing.where(subscription_id: nil).where.not(legacy_subscription_id: nil).count}"
    puts "Uncovered orphans:       #{missing.where(subscription_id: nil, order_id: nil, legacy_subscription_id: nil).count}"

    puts "\nUncovered by issue month:"
    missing.group("DATE_TRUNC('month', issued_date)").count.sort_by { |k, _| k || Time.at(0) }.each do |month, count|
      puts "  #{month&.strftime('%Y-%m') || '(no date)'}  #{count}"
    end

    puts "\n" + "-" * 80
    puts "SPOT-CHECK: 5 random invoices that already have rows (existing rows may be wrong)"
    Invoice.where(id: RevenueRecognition.select(:invoice_id)).order("RANDOM()").limit(5).each do |invoice|
      rows = invoice.revenue_recognitions.order(:period_start)
      sum = rows.sum(:recognized_amount).to_f
      flag = (sum - invoice.total_amount.to_f).abs > 0.01 ? "  ⚠ SUM MISMATCH" : ""
      puts "\n  #{RR_INVOICE_LABEL.call(invoice)}#{flag}"
      puts "    subscription start_date: #{invoice.subscription&.start_date.inspect}"
      puts "    rows sum #{RR_MONEY.call(sum)}: " +
           rows.map { |r| "#{r.period_year}-#{format('%02d', r.period_month)} #{RR_MONEY.call(r.recognized_amount)} #{r.recognition_type}" }.join(" | ")
    end

    mismatched = Invoice.joins(:revenue_recognitions)
                        .group("invoices.id", "invoices.total_amount")
                        .having("ABS(SUM(revenue_recognitions.recognized_amount) - invoices.total_amount) > 0.01")
                        .count
    puts "\nInvoices whose existing rows DON'T sum to total_amount: #{mismatched.size}"
    puts "(fix with: rake revenue_recognition:resync[<invoice_id>] or a force backfill)" if mismatched.any?

    puts "\nInvoiced vs recognized, last 12 months:"
    RR_MONTHLY_TABLE.call
  end

  desc "Dry run: print the full backfill plan without writing anything (FORCE=1 plans ALL invoices, not just uncovered)"
  task dry_run: :environment do
    force = ENV["FORCE"] == "1"
    puts "=" * 80
    puts "REVENUE RECOGNITION BACKFILL — DRY RUN (nothing written)#{' — FORCE: all invoices' if force}"
    puts "=" * 80

    results = RevenueRecognitions::Backfill.new(dry_run: true, force: force).call
    planned = results.select(&:planned?)
    exceptions = results.select(&:exception?)

    puts "\nPER-INVOICE PLAN (#{planned.size} invoices):"
    planned.each do |r|
      puts "  #{RR_INVOICE_LABEL.call(r.invoice)}"
      puts "    → #{RR_PLAN_LINE.call(r.rows)}"
    end

    puts "\nEXCEPTIONS — skipped, nothing will be written (#{exceptions.size}):"
    exceptions.each { |r| puts "  #{RR_INVOICE_LABEL.call(r.invoice)}  — #{r.reason}" }

    per_month = Hash.new(0.0)
    planned.each { |r| r.rows.each { |row| per_month[row.period_start.strftime('%Y-%m')] += row.recognized_amount } }

    puts "\nSUMMARY"
    puts "  Invoices to #{force ? 'rewrite' : 'backfill'}: #{planned.size}"
    puts "  Amount to recognize:  #{RR_MONEY.call(planned.sum { |r| r.total })}"
    puts "  Exceptions:           #{exceptions.size} (#{RR_MONEY.call(exceptions.sum { |r| r.invoice.total_amount.to_f })})"
    puts "  Recognition by service month:"
    per_month.sort.each { |month, amount| puts "    #{month}  #{RR_MONEY.call(amount)}" }
    puts "\nIf this looks right: #{force ? 'FORCE=1 ' : ''}CONFIRM=1 rake revenue_recognition:backfill"
  end

  desc "Write recognition rows for uncovered invoices (requires CONFIRM=1; FORCE=1 deletes and recreates rows for ALL invoices)"
  task backfill: :environment do
    force = ENV["FORCE"] == "1"
    unless ENV["CONFIRM"] == "1"
      abort "Refusing to write. Review `rake revenue_recognition:dry_run#{' FORCE=1' if force}` first, then re-run with CONFIRM=1."
    end

    # Months whose rows are deleted by a force pass need their metrics
    # recomputed even if no new rows land there (e.g. wrongly-future months).
    pre_months = RevenueRecognition.distinct.pluck(:period_year, :period_month)

    puts force ? "Running FORCE backfill — deleting and recreating rows for ALL invoices..." : "Running backfill..."
    results = RevenueRecognitions::Backfill.new(dry_run: false, force: force).call
    written = results.select(&:written?)
    exceptions = results.select(&:exception?)

    puts "#{force ? 'Rewrote' : 'Backfilled'} #{written.size} invoices (#{written.sum { |r| r.rows.size }} rows)."

    puts "\nEXCEPTIONS (#{exceptions.size}):"
    exceptions.each { |r| puts "  #{RR_INVOICE_LABEL.call(r.invoice)}  — #{r.reason}" }

    puts "\n" + "=" * 80
    puts "RECONCILIATION"
    puts "=" * 80
    total_invoiced = Invoice.sum(:total_amount).to_f
    total_recognized = RevenueRecognition.sum(:recognized_amount).to_f
    puts "  Total invoiced:   #{RR_MONEY.call(total_invoiced)}"
    puts "  Total recognized: #{RR_MONEY.call(total_recognized)}"
    puts "  Gap (should ≈ exceptions total): #{RR_MONEY.call(total_invoiced - total_recognized)}"

    puts "\n  Last 12 months:"
    RR_MONTHLY_TABLE.call

    puts "\n  5 LARGEST INVOICES — eyeball their schedules:"
    Invoice.order(total_amount: :desc).limit(5).each do |invoice|
      rows = invoice.revenue_recognitions.order(:period_start)
      puts "\n  #{RR_INVOICE_LABEL.call(invoice)}"
      puts rows.any? ? "    → " + rows.map { |r| "#{r.period_year}-#{format('%02d', r.period_month)} #{RR_MONEY.call(r.recognized_amount)} #{r.recognition_type}" }.join(" | ")
                     : "    → NO ROWS (see exceptions)"
    end

    puts "\nRecomputing financial_metrics for every affected month..."
    (pre_months | RevenueRecognition.distinct.pluck(:period_year, :period_month)).sort.each do |year, month|
      FinancialMetricsCalculator.new(year, month).calculate
      print "."
    rescue StandardError => e
      puts "\n  metrics failed for #{year}-#{month}: #{e.message}"
    end
    puts "\nDone."
  end

  desc "Force delete-and-recreate recognition rows for one invoice: rake revenue_recognition:resync[123]"
  task :resync, [:invoice_id] => :environment do |_t, args|
    invoice = Invoice.find(args[:invoice_id])
    result = RevenueRecognitions::Recognize.new(invoice).call(force: true)
    puts RR_INVOICE_LABEL.call(invoice)
    if result.written?
      puts "  → #{RR_PLAN_LINE.call(result.rows)}"
      result.months.each { |y, m| FinancialMetricsCalculator.new(y, m).calculate }
      puts "  financial_metrics recomputed for #{result.months.size} month(s)."
    else
      puts "  NOT WRITTEN: #{result.reason}"
    end
  end
end
