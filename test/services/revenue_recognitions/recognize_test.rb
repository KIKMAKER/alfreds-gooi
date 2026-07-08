require "test_helper"

module RevenueRecognitions
  class RecognizeTest < ActiveSupport::TestCase
    def setup
      @user = User.create!(
        email: "rev-rec-#{SecureRandom.hex(4)}@example.com",
        password: "password",
        phone_number: "+27800000002"
      )
    end

    def build_subscription(plan: "Standard", duration: 3, monthly_invoicing: false, start_date: nil)
      attrs = {
        user: @user,
        plan: plan,
        duration: duration,
        monthly_invoicing: monthly_invoicing,
        start_date: start_date,
        street_address: "1 Test St",
        suburb: "Rondebosch"
      }
      attrs.merge!(bucket_size: 45, buckets_per_collection: 2) if plan == "Commercial"
      Subscription.create!(attrs)
    end

    def build_product(title:, price:)
      Product.create!(title: title, price: price, description: title, billing_type: "standard")
    end

    def build_invoice(subscription: nil, order: nil, total: 450.0, issued: Date.new(2026, 3, 5))
      Invoice.create!(
        subscription: subscription,
        order: order,
        issued_date: issued,
        due_date: issued + 14,
        total_amount: total
      )
    end

    # --- term subscription spreads ---

    test "1-month subscription recognizes fully in issue month" do
      invoice = build_invoice(subscription: build_subscription(duration: 1), total: 250.0)
      rows = Recognize.new(invoice).plan.rows

      assert_equal 1, rows.size
      assert_equal 250.0, rows[0].recognized_amount
      assert_equal [2026, 3], [rows[0].period_start.year, rows[0].period_start.month]
      assert_equal "service", rows[0].recognition_type
    end

    test "3-month subscription spreads evenly from issue month" do
      invoice = build_invoice(subscription: build_subscription(duration: 3), total: 450.0)
      rows = Recognize.new(invoice).plan.rows

      assert_equal 3, rows.size
      assert_equal [150.0, 150.0, 150.0], rows.map(&:recognized_amount)
      assert_equal [[2026, 3], [2026, 4], [2026, 5]],
                   rows.map { |r| [r.period_start.year, r.period_start.month] }
      assert rows.all? { |r| r.recognition_type == "service" }
    end

    test "6-month spread puts the rounding remainder on the final month" do
      invoice = build_invoice(subscription: build_subscription(duration: 6), total: 100.0)
      rows = Recognize.new(invoice).plan.rows

      assert_equal 6, rows.size
      assert_equal [16.66] * 5 + [16.70], rows.map(&:recognized_amount)
      assert_in_delta 100.0, rows.sum(&:recognized_amount), 0.001
    end

    test "spread starts at subscription start_date when it falls just after issue" do
      sub = build_subscription(duration: 3, start_date: Date.new(2026, 3, 20))
      invoice = build_invoice(subscription: sub, issued: Date.new(2026, 3, 5))
      rows = Recognize.new(invoice).plan.rows

      assert_equal Date.new(2026, 3, 20), rows[0].period_start
      assert_equal [[2026, 3], [2026, 4], [2026, 5]],
                   rows.map { |r| [r.period_start.year, r.period_start.month] }
    end

    test "spread ignores a stale start_date far before the invoice (renewal)" do
      sub = build_subscription(duration: 3, start_date: Date.new(2025, 6, 1))
      invoice = build_invoice(subscription: sub, issued: Date.new(2026, 3, 5))
      rows = Recognize.new(invoice).plan.rows

      assert_equal [[2026, 3], [2026, 4], [2026, 5]],
                   rows.map { |r| [r.period_start.year, r.period_start.month] }
    end

    # --- monthly invoicing ---

    test "monthly_invoicing subscription recognizes fully in issue month" do
      sub = build_subscription(plan: "Commercial", duration: 12, monthly_invoicing: true)
      invoice = build_invoice(subscription: sub, total: 1200.0)
      rows = Recognize.new(invoice).plan.rows

      assert_equal 1, rows.size
      assert_equal 1200.0, rows[0].recognized_amount
      assert_equal [2026, 3], [rows[0].period_start.year, rows[0].period_start.month]
    end

    # --- once-off and orders ---

    test "once_off plan recognizes in the month of its collection" do
      sub = build_subscription(plan: "once_off", duration: nil)
      Collection.create!(subscription: sub, date: Date.new(2026, 4, 10))
      invoice = build_invoice(subscription: sub, total: 120.0)
      rows = Recognize.new(invoice).plan.rows

      assert_equal 1, rows.size
      assert_equal [2026, 4], [rows[0].period_start.year, rows[0].period_start.month]
      assert_equal "one_off", rows[0].recognition_type
    end

    test "order-linked invoice recognizes in the linked collection's month" do
      sub = build_subscription(duration: 3)
      collection = Collection.create!(subscription: sub, date: Date.new(2026, 4, 15))
      order = Order.create!(user: @user, status: :paid, collection: collection, total_amount: 90.0)
      invoice = build_invoice(subscription: sub, order: order, total: 90.0)
      rows = Recognize.new(invoice).plan.rows

      assert_equal 1, rows.size
      assert_equal [2026, 4], [rows[0].period_start.year, rows[0].period_start.month]
      assert_equal "one_off", rows[0].recognition_type
    end

    # --- mixed one-off + service items ---

    test "starter kit items recognize in issue month, service portion spreads" do
      sub = build_subscription(duration: 3)
      kit = build_product(title: "Standard Starter Kit", price: 250.0)
      plan_product = build_product(title: "Standard 3 month subscription", price: 450.0)

      invoice = build_invoice(subscription: sub, total: 0)
      invoice.invoice_items.create!(product: kit, quantity: 1, amount: 250.0)
      invoice.invoice_items.create!(product: plan_product, quantity: 1, amount: 450.0)
      invoice.calculate_total

      rows = Recognize.new(invoice.reload).plan.rows
      one_off = rows.select { |r| r.recognition_type == "one_off" }
      service = rows.select { |r| r.recognition_type == "service" }

      assert_equal 1, one_off.size
      assert_equal 250.0, one_off[0].recognized_amount
      assert_equal [2026, 3], [one_off[0].period_start.year, one_off[0].period_start.month]
      assert_equal 3, service.size
      assert_equal [150.0, 150.0, 150.0], service.map(&:recognized_amount)
      assert_in_delta 700.0, rows.sum(&:recognized_amount), 0.001
    end

    test "falls back to spreading the whole invoice when the split is unreliable" do
      sub = build_subscription(duration: 3)
      kit = build_product(title: "Standard Starter Kit", price: 250.0)

      # Discounted total below the one-off portion → split would go negative
      invoice = build_invoice(subscription: sub, total: 200.0)
      invoice.invoice_items.create!(product: kit, quantity: 1, amount: 250.0)

      rows = Recognize.new(invoice.reload).plan.rows
      assert rows.all? { |r| r.recognition_type == "service" }
      assert_in_delta 200.0, rows.sum(&:recognized_amount), 0.001
    end

    # --- exceptions ---

    test "legacy-only invoice is an exception and writes nothing" do
      invoice = Invoice.new(issued_date: Date.today, due_date: Date.today + 14,
                            total_amount: 100.0, legacy_subscription_id: 42)
      invoice.save!
      result = Recognize.new(invoice).call

      assert result.exception?
      assert_match(/legacy_subscription_id=42/, result.reason)
      assert_equal 0, invoice.revenue_recognitions.count
    end

    test "zero-total invoice gets a single zero row" do
      invoice = build_invoice(subscription: build_subscription(duration: 3), total: 0.0)
      rows = Recognize.new(invoice).plan.rows

      assert_equal 1, rows.size
      assert_equal 0.0, rows[0].recognized_amount
    end

    # --- write path ---

    test "call is idempotent: never duplicates rows for a covered invoice" do
      invoice = build_invoice(subscription: build_subscription(duration: 3), total: 450.0)
      Recognize.new(invoice).call
      count = invoice.revenue_recognitions.count
      assert_equal 3, count

      result = Recognize.new(invoice).call
      assert_equal :skipped_existing, result.status
      assert_equal count, invoice.revenue_recognitions.count
    end

    test "force deletes and recreates rows" do
      invoice = build_invoice(subscription: build_subscription(duration: 3), total: 450.0)
      Recognize.new(invoice).call
      stale_ids = invoice.revenue_recognitions.pluck(:id)

      result = Recognize.new(invoice.reload).call(force: true)
      assert result.written?
      assert_equal 3, invoice.revenue_recognitions.count
      assert_empty stale_ids & invoice.revenue_recognitions.pluck(:id)
    end

    test "written rows sum exactly to total_amount" do
      invoice = build_invoice(subscription: build_subscription(duration: 6), total: 1234.56)
      Recognize.new(invoice).call(force: true)

      assert_in_delta invoice.total_amount,
                      invoice.revenue_recognitions.sum(:recognized_amount).to_f, 0.005
    end
  end
end
