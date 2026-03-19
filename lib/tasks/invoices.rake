namespace :invoices do
  desc "Audit (and optionally fix) compost-bag invoices missing order_id.
        Modes: dry_run (default), live
        Usage: rake invoices:backfill_order_ids
               rake invoices:backfill_order_ids[live]"

  task :backfill_order_ids, [:mode] => :environment do |_t, args|
    mode = (args[:mode] || "dry_run").downcase

    # --- find the product once ---
    compost_bag = Product.find_by(title: "Compost bin bags")
    abort "❌  Product 'Compost bin bags' not found" unless compost_bag

    # --- candidate invoices: paid, no order_id, total is a multiple of 90 and < 720,
    #     and has at least one compost bag invoice item ---
    candidate_invoice_ids = InvoiceItem
      .where(product_id: compost_bag.id)
      .pluck(:invoice_id)

    candidates = Invoice
      .where(id: candidate_invoice_ids, paid: true, order_id: nil)
      .where("total_amount > 0 AND total_amount < 720 AND CAST(total_amount AS INTEGER) % 90 = 0")
      .includes(subscription: :user)
      .order(:issued_date)

    stats = { total: 0, matched: 0, ambiguous: 0, no_order: 0, no_user: 0, fixed: 0 }

    puts "=" * 70
    puts "  Compost bag invoice → order backfill  [#{mode.upcase}]"
    puts "=" * 70

    candidates.each do |invoice|
      stats[:total] += 1
      user = invoice.subscription&.user

      unless user
        stats[:no_user] += 1
        puts "  ⚠️  Invoice ##{invoice.number || invoice.id}  — no user via subscription, skipping"
        next
      end

      # Orders for this user containing compost bags with a matching total,
      # ordered by proximity to the invoice issued_date
      matching_orders = user.orders
        .joins(:order_items)
        .where(order_items: { product_id: compost_bag.id })
        .where(total_amount: invoice.total_amount)
        .order(Arel.sql("ABS(EXTRACT(EPOCH FROM (orders.created_at - '#{invoice.issued_date}'::date)))"))

      case matching_orders.count
      when 0
        stats[:no_order] += 1
        puts "  ❌  Invoice ##{invoice.number || invoice.id}  R#{invoice.total_amount.to_i}  #{invoice.issued_date}  — no matching order for #{user.customer_id}"
      when 1
        stats[:matched] += 1
        order = matching_orders.first
        puts "  ✓   Invoice ##{invoice.number || invoice.id}  R#{invoice.total_amount.to_i}  #{invoice.issued_date}  → Order ##{order.id}  (#{user.customer_id})"
        if mode == "live"
          invoice.update_column(:order_id, order.id)
          stats[:fixed] += 1
        end
      else
        stats[:ambiguous] += 1
        puts "  ⚠️  Invoice ##{invoice.number || invoice.id}  R#{invoice.total_amount.to_i}  #{invoice.issued_date}  — #{matching_orders.count} orders match for #{user.customer_id}, skipping"
      end
    end

    puts "=" * 70
    puts "  Total candidates : #{stats[:total]}"
    puts "  Matched (1:1)    : #{stats[:matched]}"
    puts "  No matching order: #{stats[:no_order]}"
    puts "  Ambiguous        : #{stats[:ambiguous]}"
    puts "  No user          : #{stats[:no_user]}" if stats[:no_user] > 0
    puts "  Fixed            : #{stats[:fixed]}" if mode == "live"
    puts "=" * 70

    if mode != "live"
      puts "\n🔍  DRY RUN — no changes made"
      puts "    To fix: rake invoices:backfill_order_ids[live]"
    else
      puts "\n✅  Live run complete"
    end
  end
end
