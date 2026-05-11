namespace :payments do
  desc "Backfill payment records for invoices marked paid with no payment row. DRY_RUN=true (default) to preview."
  task backfill_from_paid_invoices: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"

    puts dry_run ? "=== DRY RUN — no records will be written ===" : "=== LIVE RUN — creating payment records ==="
    puts

    orphaned = Invoice
      .where(paid: true)
      .left_joins(:payments)
      .where(payments: { id: nil })
      .includes(:subscription)
      .order(:issued_date)

    skipped = []
    to_create = []

    orphaned.each do |invoice|
      user = invoice.subscription&.user
      unless user
        skipped << "Invoice ##{invoice.number} R#{invoice.total_amount} #{invoice.issued_date} — no subscription/user, skipping"
        next
      end

      to_create << {
        invoice:      invoice,
        user:         user,
        total_cents:  (invoice.total_amount * 100).round,
        date:         invoice.issued_date
      }
    end

    if skipped.any?
      puts "SKIPPED (#{skipped.count}):"
      skipped.each { |msg| puts "  ⚠️  #{msg}" }
      puts
    end

    puts "TO CREATE (#{to_create.count}):"
    to_create.each do |r|
      puts "  Invoice ##{r[:invoice].number} | R#{r[:invoice].total_amount} | #{r[:date]} | user: #{r[:user].email}"
    end
    puts

    unless dry_run
      created = 0
      to_create.each do |r|
        Payment.create!(
          user:         r[:user],
          invoice:      r[:invoice],
          total_amount: r[:total_cents],
          date:         r[:date],
          payment_type: :other,
          manual:       true,
          note:         "backfilled — invoice marked paid, no payment record existed"
        )
        created += 1
      end
      puts "✅ Created #{created} payment records."
    else
      puts "Run with DRY_RUN=false to write #{to_create.count} records."
    end
  end
end
