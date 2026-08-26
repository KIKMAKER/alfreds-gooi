require "test_helper"

class Subscriptions::UsageTrueUpTest < ActiveSupport::TestCase
  def setup
    @volume_product = Product.create!(
      title: "Commercial volume per 45L bucket", description: "test", price: 76.5,
      billing_type: "standard"
    )
  end

  def build_commercial_subscription(**attrs)
    user = User.create!(
      first_name: "Test", last_name: "Commercial", email: "utu-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    Subscription.create!({
      user: user, plan: "Commercial", status: :active,
      street_address: "1 Test St", suburb: suburb_fixture("Claremont"),
      duration: 6, buckets_per_collection: 2, bucket_size: 45, collections_per_week: 1,
      start_date: 3.months.ago, volume_processing_product: @volume_product
    }.merge(attrs))
  end

  def add_collection(subscription, date:, buckets_45l:)
    subscription.collections.create!(date: date, skip: false, buckets_45l: buckets_45l)
  end

  test "monthly-invoicing sub with excess usage generates a catch-up invoice and updates cached billing fields" do
    sub = build_commercial_subscription(
      monthly_invoicing: true,
      monthly_subscription_amount: 260.0,
      monthly_volume_amount: 273.33,
      starter_kit_installment: 35.0
    )
    # contracted 2 buckets/collection; actual 4 buckets/collection across 4 collections
    4.times { |i| add_collection(sub, date: (i + 1).weeks.ago.to_date, buckets_45l: 4) }

    result = Subscriptions::UsageTrueUp.new(sub).create_invoice!(new_buckets_per_collection: 4)

    assert result.success, result.error
    invoice = sub.invoices.order(:created_at).last
    assert_equal 1, invoice.invoice_items.count
    assert invoice.total_amount.positive?

    sub.reload
    assert_equal 4, sub.buckets_per_collection
    assert_equal Date.today, sub.last_usage_review_date
    assert_not_equal 273.33, sub.monthly_volume_amount
  end

  test "upfront-paid sub bills catch-up plus the remaining contract term" do
    sub = build_commercial_subscription(monthly_invoicing: false)
    original_invoice = Invoice.create!(subscription: sub, issued_date: 3.months.ago, due_date: 3.months.ago, total_amount: 0, admin_approved: true)
    original_invoice.invoice_items.create!(product: @volume_product, quantity: 25, amount: 153.0) # 2 buckets * price/bucket per visit

    4.times { |i| add_collection(sub, date: (i + 1).weeks.ago.to_date, buckets_45l: 4) }

    result = Subscriptions::UsageTrueUp.new(sub).create_invoice!(new_buckets_per_collection: 4)

    assert result.success, result.error
    invoice = sub.invoices.order(:created_at).last
    assert_equal 2, invoice.invoice_items.count
  end

  test "falls back to the catalog per-litre rate (not a whole-contract amortization) when no original volume line item exists" do
    sub = build_commercial_subscription(monthly_invoicing: false) # no invoices at all — forces the fallback branch
    4.times { |i| add_collection(sub, date: (i + 1).weeks.ago.to_date, buckets_45l: 4) }

    review = Subscriptions::UsageTrueUp.new(sub).review

    # price 76.5 / bucket_size 45 = R1.70/L — not divided by contract visit count
    expected_rate = @volume_product.price / sub.bucket_size
    assert_in_delta review.excess_litres * expected_rate, review.catch_up_amount, 0.01
  end

  test "returns an error and creates no invoice when usage already matches the contract" do
    sub = build_commercial_subscription(monthly_invoicing: false)
    Invoice.create!(subscription: sub, issued_date: 3.months.ago, due_date: 3.months.ago, total_amount: 0, admin_approved: true)
      .invoice_items.create!(product: @volume_product, quantity: 25, amount: 153.0)

    2.times { |i| add_collection(sub, date: (i + 1).weeks.ago.to_date, buckets_45l: 2) }

    invoice_count_before = Invoice.count
    result = Subscriptions::UsageTrueUp.new(sub).create_invoice!(new_buckets_per_collection: 2)

    assert_not result.success
    assert_equal invoice_count_before, Invoice.count
  end

  test "monthly-invoicing sub with no historical excess still persists a capacity increase, with no invoice" do
    sub = build_commercial_subscription(
      monthly_invoicing: true,
      monthly_subscription_amount: 260.0,
      monthly_volume_amount: 121.33,
      starter_kit_installment: 35.0
    )
    # contracted 2 buckets/collection; actual usage stays within contract
    4.times { |i| add_collection(sub, date: (i + 1).weeks.ago.to_date, buckets_45l: 2) }

    invoice_count_before = Invoice.count
    result = Subscriptions::UsageTrueUp.new(sub).create_invoice!(new_buckets_per_collection: 3)

    assert result.success, result.error
    assert_equal invoice_count_before, Invoice.count

    sub.reload
    assert_equal 3, sub.buckets_per_collection
    assert_equal Date.today, sub.last_usage_review_date
    assert_not_equal 121.33, sub.monthly_volume_amount
  end

  test "combines a satellite subscription's usage into the primary's review" do
    primary = build_commercial_subscription(monthly_invoicing: true, monthly_subscription_amount: 260.0, monthly_volume_amount: 273.33, starter_kit_installment: 35.0)
    satellite = build_commercial_subscription(monthly_invoicing: true, primary_subscription: primary, buckets_per_collection: 2, bucket_size: 45)

    # primary stays within contract; satellite runs well over
    add_collection(primary, date: 1.week.ago.to_date, buckets_45l: 2)
    4.times { |i| add_collection(satellite, date: (i + 1).weeks.ago.to_date, buckets_45l: 5) }

    review = Subscriptions::UsageTrueUp.new(primary).review

    assert review.actual_litres > review.contracted_litres
    assert review.excess_litres.positive?
  end
end
