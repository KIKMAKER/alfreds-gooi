require "test_helper"

module RevenueRecognitions
  class BackfillTest < ActiveSupport::TestCase
    def setup
      @user = User.create!(
        email: "rev-backfill-#{SecureRandom.hex(4)}@example.com",
        password: "password",
        phone_number: "+27800000003"
      )
      @subscription = Subscription.create!(
        user: @user,
        plan: "Standard",
        duration: 3,
        street_address: "1 Test St",
        suburb: "Rondebosch"
      )
    end

    def bare_invoice(total:, issued: Date.new(2026, 2, 1), subscription: @subscription, legacy: nil)
      invoice = Invoice.create!(
        subscription: subscription,
        legacy_subscription_id: legacy,
        issued_date: issued,
        due_date: issued + 14,
        total_amount: total
      )
      # Simulate the historical gap: strip the rows the creation hook made
      invoice.revenue_recognitions.delete_all
      invoice
    end

    test "dry run plans but writes nothing" do
      invoice = bare_invoice(total: 300.0)
      results = Backfill.new(dry_run: true).call

      planned = results.find { |r| r.invoice.id == invoice.id }
      assert planned.planned?
      assert_equal 3, planned.rows.size
      assert_equal 0, invoice.revenue_recognitions.count
    end

    test "real run covers uncovered invoices and skips covered ones" do
      uncovered = bare_invoice(total: 300.0)
      covered = Invoice.create!(subscription: @subscription, issued_date: Date.new(2026, 2, 1),
                                due_date: Date.new(2026, 2, 15), total_amount: 90.0)
      covered_rows = covered.revenue_recognitions.order(:id).pluck(:id)
      assert covered_rows.any?, "creation hook should have covered this invoice"

      Backfill.new(dry_run: false).call

      assert_equal 3, uncovered.revenue_recognitions.count
      assert_equal covered_rows, covered.revenue_recognitions.order(:id).pluck(:id),
                   "existing rows must not be touched without force"
    end

    test "re-running never duplicates rows" do
      invoice = bare_invoice(total: 300.0)
      Backfill.new(dry_run: false).call
      Backfill.new(dry_run: false).call

      assert_equal 3, invoice.revenue_recognitions.count
    end

    test "unresolvable invoices land in exceptions, not the table" do
      orphan = bare_invoice(total: 500.0, subscription: nil, legacy: 99)
      results = Backfill.new(dry_run: false).call

      exception = results.find { |r| r.invoice.id == orphan.id }
      assert exception.exception?
      assert_equal 0, orphan.revenue_recognitions.count
    end

    test "reconciliation: recognized totals equal invoiced totals for resolvable invoices" do
      monthly_sub = Subscription.create!(
        user: @user, plan: "Commercial", duration: 12, monthly_invoicing: true,
        street_address: "2 Test St", suburb: "Rondebosch",
        bucket_size: 45, buckets_per_collection: 2
      )
      invoices = [
        bare_invoice(total: 450.0),
        bare_invoice(total: 1234.56),
        bare_invoice(total: 890.0, subscription: monthly_sub)
      ]

      Backfill.new(dry_run: false).call

      invoiced = invoices.sum(&:total_amount)
      recognized = RevenueRecognition.where(invoice_id: invoices.map(&:id)).sum(:recognized_amount).to_f
      assert_in_delta invoiced, recognized, 0.01
    end
  end
end
