require "test_helper"

module RevenueRecognitions
  # The protein products must flow through the existing recognition engine unchanged.
  # Recognize splits one-off items by matching product titles against ONE_OFF_TITLES
  # (/starter kit|starter bucket|.../i) — "Protein Starter Bucket" already matches, so
  # no engine change is needed. This test is the proof.
  class ProteinRecognitionTest < ActiveSupport::TestCase
    def setup
      @user = User.create!(
        email:        "protein-rec-#{SecureRandom.hex(4)}@example.com",
        password:     "password",
        phone_number: "+27800000050"
      )

      @subscription = Subscription.create!(
        user:                   @user,
        plan:                   "Commercial",
        waste_stream:           :protein,
        collections_per_week:   3,
        duration:               6,
        start_date:             Date.new(2026, 3, 1),
        street_address:         "18 Kloof Street, Gardens",
        suburb:                 "Gardens",
        bucket_size:            25,
        buckets_per_collection: 2
      )

      @starter_bucket = Product.create!(
        title:        "Protein Starter Bucket (25L sealed, swap pair)",
        description:  "Pair of 25L sealed swap buckets",
        price:        320.0,
        billing_type: "standard"
      )
      @volume = Product.create!(
        title:        "Protein Volume Processing per 25L (6-month rate)",
        description:  "Protein volume processing",
        price:        1300.0,
        billing_type: "standard"
      )
    end

    # Mirrors InvoiceBuilder: create the invoice, add the items, then calculate_total —
    # which is what fires the recognition sync with the items in place.
    def build_protein_invoice
      invoice = Invoice.create!(
        subscription: @subscription,
        issued_date:  Date.new(2026, 3, 5),
        due_date:     Date.new(2026, 3, 19),
        total_amount: 0
      )
      invoice.invoice_items.create!(product: @starter_bucket, quantity: 1, amount: 320.0)
      invoice.invoice_items.create!(product: @volume, quantity: 1, amount: 1300.0)
      invoice.calculate_total
      invoice
    end

    test "the starter bucket recognises as one_off and the service spreads over the term" do
      result = Recognize.new(build_protein_invoice).plan
      rows   = result.rows

      one_offs = rows.select { |r| r.recognition_type == "one_off" }
      services = rows.select { |r| r.recognition_type == "service" }

      assert_equal 1, one_offs.size
      assert_equal 320.0, one_offs.first.recognized_amount,
                   "the sealed swap-bucket pair is a one-off purchase"
      assert_equal [2026, 3],
                   [one_offs.first.period_start.year, one_offs.first.period_start.month]

      assert_equal 6, services.size, "the 6-month protein service spreads across the term"
      assert_in_delta 1300.0, services.sum(&:recognized_amount), 0.01
      assert_in_delta 1620.0, result.total, 0.01, "rows must sum to the invoice total"
    end

    test "a protein invoice gets recognition rows with no engine changes" do
      invoice = build_protein_invoice

      # The Invoice hook syncs recognitions on its own — nothing protein-specific
      # was added to the engine.
      assert_equal 1620.0, invoice.total_amount
      assert_equal 7, invoice.revenue_recognitions.count,
                   "1 one-off row for the starter bucket + 6 service rows for the term"
      assert_in_delta 1620.0, invoice.revenue_recognitions.sum(:recognized_amount), 0.01

      one_off = invoice.revenue_recognitions.find_by(recognition_type: "one_off")
      assert_equal 320.0, one_off.recognized_amount.to_f
    end

    test "protein products are selectable on a quote" do
      assert_includes Product.quote_eligible, @volume
      assert_includes Product.quote_eligible, @starter_bucket
    end
  end
end
