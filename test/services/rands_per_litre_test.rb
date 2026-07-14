require "test_helper"

class RandsPerLitreTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "rpl-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      phone_number: "+27800000005"
    )
  end

  def build_subscription(plan: "Standard", duration: 3, **attrs)
    defaults = {
      user: @user,
      plan: plan,
      duration: duration,
      street_address: "1 Test St",
      suburb: "Rondebosch",
      status: :active
    }
    defaults.merge!(bucket_size: 45, buckets_per_collection: 2) if plan == "Commercial"
    Subscription.create!(defaults.merge(attrs))
  end

  def build_invoice(subscription:, total:, order: nil)
    Invoice.create!(
      subscription: subscription,
      order: order,
      issued_date: Date.today,
      due_date: Date.today + 14,
      total_amount: total
    )
  end

  # --- invoices ---

  test "term Standard invoice: total over duration x 4 weeks x 5L" do
    invoice = build_invoice(subscription: build_subscription(duration: 3), total: 660.0)
    result = RandsPerLitre.for(invoice)

    # 12 weeks x 5L = 60L → R11/L
    assert_equal 60, result.litres
    assert_equal 11.0, result.rate
  end

  test "monthly Commercial invoice: one month of contracted volume" do
    sub = build_subscription(plan: "Commercial", duration: 12, monthly_invoicing: true,
                             collections_per_week: 1)
    invoice = build_invoice(subscription: sub, total: 1800.0)
    result = RandsPerLitre.for(invoice)

    # 2 buckets x 45L x 1/week x 4 weeks = 360L → R5/L
    assert_equal 360, result.litres
    assert_equal 5.0, result.rate
  end

  test "combined monthly invoice counts all the user's active monthly subs" do
    sub_a = build_subscription(plan: "Commercial", duration: 12, monthly_invoicing: true,
                               collections_per_week: 1)
    build_subscription(plan: "Commercial", duration: 12, monthly_invoicing: true,
                       collections_per_week: 1, street_address: "2 Test St")
    invoice = build_invoice(subscription: sub_a, total: 3600.0)
    result = RandsPerLitre.for(invoice)

    # Two locations: 720L total → R5/L, not R10/L
    assert_equal 720, result.litres
    assert_equal 5.0, result.rate
    assert_match(/across 2 subscriptions/, result.note)
  end

  test "once-off invoice uses a single collection's litres" do
    sub = build_subscription(plan: "once_off", duration: nil)
    invoice = build_invoice(subscription: sub, total: 100.0)
    result = RandsPerLitre.for(invoice)

    assert_equal 5, result.litres
    assert_equal 20.0, result.rate
  end

  test "order invoices and zero totals have no badge" do
    sub = build_subscription
    order = Order.create!(user: @user, status: :paid, total_amount: 90.0)

    assert_nil RandsPerLitre.for(build_invoice(subscription: sub, total: 90.0, order: order))
    assert_nil RandsPerLitre.for(build_invoice(subscription: sub, total: 0.0))
  end

  # --- quotations ---

  def build_quotation(**attrs)
    Quotation.create!({
      prospect_name: "Test Prospect",
      prospect_email: "prospect@example.com",
      created_date: Date.today,
      expires_at: Date.today + 30,
      duration_months: 6,
      collections_per_week: 2,
      buckets_per_collection: 3,
      total_amount: 6480.0
    }.merge(attrs))
  end

  test "quotation rate from buckets and inferred bucket size" do
    quotation = build_quotation
    product = Product.create!(title: "Commercial volume per 45L bucket", price: 30.0,
                              description: "vol", billing_type: "standard")
    quotation.quotation_items.create!(product: product, quantity: 1, amount: 30.0)

    result = RandsPerLitre.for(quotation)

    # 3 x 45L x 2/week x 24 weeks = 6480L → R1/L
    assert_equal 6480, result.litres
    assert_equal 1.0, result.rate
  end

  test "event quotes and quotes without volume data have no badge" do
    assert_nil RandsPerLitre.for(build_quotation(quote_type: "event", event_date: Date.today + 7))
    # No bucket-size product on the quote and no linked subscription
    assert_nil RandsPerLitre.for(build_quotation)
  end
end
