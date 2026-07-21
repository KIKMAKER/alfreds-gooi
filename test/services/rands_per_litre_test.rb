require "test_helper"

class RandsPerLitreTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "rpl-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      phone_number: "+27800000005"
    )
  end

  def build_subscription(plan: "Standard", monthly_subscription_amount:, monthly_volume_amount: 0,
                         starter_kit_installment: nil, start_date: 6.months.ago, end_date: nil, **attrs)
    defaults = {
      user: @user,
      plan: plan,
      duration: 3,
      street_address: "1 Test St",
      suburb: suburb_fixture("Rondebosch"),
      status: :active,
      monthly_subscription_amount: monthly_subscription_amount,
      monthly_volume_amount: monthly_volume_amount,
      starter_kit_installment: starter_kit_installment,
      start_date: start_date,
      end_date: end_date
    }
    defaults.merge!(bucket_size: 45, buckets_per_collection: 2, collections_per_week: 1) if plan == "Commercial"
    Subscription.create!(defaults.merge(attrs))
  end

  # --- contracted_r_per_litre: subscriptions ---

  test "Standard plan: monthly charge over the 18L/month seeded average" do
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0)
    result = RandsPerLitre.for(sub)

    assert_equal 18.0, result.litres
    assert_in_delta 12.22, result.rate, 0.01
  end

  test "XL plan: monthly charge over the 62L/month seeded average" do
    sub = build_subscription(plan: "XL", monthly_subscription_amount: 300.0)
    result = RandsPerLitre.for(sub)

    assert_equal 62.0, result.litres
    assert_in_delta 4.84, result.rate, 0.01
  end

  test "Commercial plan: litres derived from the subscription's own bucket size and frequency" do
    sub = build_subscription(plan: "Commercial", monthly_subscription_amount: 500.0, monthly_volume_amount: 1000.0,
                             bucket_size: 45, buckets_per_collection: 2, collections_per_week: 2)
    result = RandsPerLitre.for(sub)

    # 2 buckets x 45L x 2/week x 4 weeks = 720L
    assert_equal 720, result.litres
    assert_in_delta(1500.0 / 720, result.rate, 0.01)
  end

  test "identical plan and price give identical contracted R/L regardless of subscription age or collection history" do
    old_sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0, start_date: 2.years.ago)
    new_sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0, start_date: 2.days.ago)

    # Old subscription has months of real collection history; new one has none.
    old_sub.collections.create!(date: 1.month.ago.to_date, bags: 3, skip: false)

    assert_equal RandsPerLitre.for(old_sub).rate, RandsPerLitre.for(new_sub).rate
  end

  test "once_off has no contracted rate" do
    sub = build_subscription(plan: "once_off", monthly_subscription_amount: 100.0)
    assert_nil RandsPerLitre.for(sub)
  end

  test "a Commercial subscription never billed (no cached monthly amount yet) has no contracted rate" do
    sub = build_subscription(plan: "Commercial", monthly_subscription_amount: nil)
    assert_nil RandsPerLitre.for(sub)
  end

  test "a Standard/XL subscription with no cached amount falls back to its own subscription_product's price" do
    # InvoiceBuilder#add_subscription_product refreshes subscription_product_id on
    # every invoice (new or renewal) for non-monthly-invoicing Standard/XL subs, so
    # it's the reliable pointer to what this subscription actually pays — unlike
    # monthly_subscription_amount, which only ever gets cached on the very first invoice.
    Product.create!(title: "Standard 3 month subscription", price: 999.0,
                    description: "generic rate card — must NOT be used", billing_type: "invoice_only")
    linked = Product.create!(title: "Standard 3 month subscription (this customer's actual product)",
                             price: 660.0, description: "plan", billing_type: "invoice_only")
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: nil, duration: 3,
                             subscription_product: linked)

    result = RandsPerLitre.for(sub)

    # 660 / 3 months = R220/mo ÷ 18L = R12.22/L — from the linked product, not the generic-titled one
    assert_in_delta 12.22, result.rate, 0.01
  end

  test "an OG subscription with no cached amount shows a different rate than a non-OG one at the same duration" do
    # InvoiceBuilder#add_subscription_product picks between a "<plan> <duration> month
    # subscription" and a "<plan> <duration> month OG subscription" Product depending on
    # the customer, at a different price. Guessing the plain title (ignoring
    # subscription_product) would charge every OG subscriber as if paying full price.
    og_product     = Product.create!(title: "Standard 6 month OG subscription", price: 720.0,
                                     description: "OG rate", billing_type: "invoice_only")
    non_og_product = Product.create!(title: "Standard 6 month subscription", price: 1080.0,
                                     description: "standard rate", billing_type: "invoice_only")
    og_sub     = build_subscription(plan: "Standard", monthly_subscription_amount: nil, duration: 6,
                                    subscription_product: og_product)
    non_og_sub = build_subscription(plan: "Standard", monthly_subscription_amount: nil, duration: 6,
                                    subscription_product: non_og_product)

    og_rate     = RandsPerLitre.for(og_sub).rate
    non_og_rate = RandsPerLitre.for(non_og_sub).rate

    # OG: 720/6/18 = R6.67/L. Non-OG: 1080/6/18 = R10.00/L.
    assert_in_delta 6.67, og_rate, 0.01
    assert_in_delta 10.00, non_og_rate, 0.01
    refute_equal og_rate, non_og_rate
  end

  test "a Standard/XL subscription with no cache, no linked product, and no matching rate-card product has no contracted rate" do
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: nil, duration: 3)
    assert_nil RandsPerLitre.for(sub)
  end

  test "falls back to the generic rate-card title only when there's no linked subscription_product at all" do
    Product.create!(title: "Standard 3 month subscription", price: 660.0,
                    description: "plan", billing_type: "invoice_only")
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: nil, duration: 3)

    result = RandsPerLitre.for(sub)

    assert_in_delta 12.22, result.rate, 0.01
  end

  test "starter kit installment never affects the contracted rate" do
    without_kit = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0, starter_kit_installment: nil)
    with_kit    = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0, starter_kit_installment: 150.0)

    assert_equal RandsPerLitre.for(without_kit).rate, RandsPerLitre.for(with_kit).rate
  end

  test "expected_monthly_litres includes satellite subscriptions' volume" do
    primary = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0)
    build_subscription(plan: "Standard", monthly_subscription_amount: 0, primary_subscription: primary)

    assert_equal 36.0, PlanVolume.expected_monthly_litres(primary)
  end

  # --- contracted_r_per_litre: invoices ---

  test "every invoice for a subscription shows the same contracted rate, regardless of which one" do
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0)
    old_invoice = Invoice.create!(subscription: sub, issued_date: 3.months.ago, due_date: 3.months.ago + 14, total_amount: 999.0)
    new_invoice = Invoice.create!(subscription: sub, issued_date: Date.today, due_date: Date.today + 14, total_amount: 1.0)

    assert_equal RandsPerLitre.for(sub).rate, RandsPerLitre.for(old_invoice).rate
    assert_equal RandsPerLitre.for(sub).rate, RandsPerLitre.for(new_invoice).rate
  end

  test "order invoices have no badge" do
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0)
    order = Order.create!(user: @user, status: :paid, total_amount: 90.0)
    invoice = Invoice.create!(subscription: sub, order: order, issued_date: Date.today, due_date: Date.today + 14, total_amount: 90.0)

    assert_nil RandsPerLitre.for(invoice)
  end

  # --- contracted_r_per_litre: quotations ---

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

  test "commercial quote: expected litres derived from the quote's own line items, never from collections" do
    quotation = build_quotation
    product = Product.create!(title: "Commercial volume per 45L bucket", price: 30.0,
                              description: "vol", billing_type: "standard")
    quotation.quotation_items.create!(product: product, quantity: 1, amount: 30.0)

    litres = PlanVolume.expected_monthly_litres_for_quotation(quotation)
    result = RandsPerLitre.for(quotation)

    # 3 buckets x 45L x 2/week x 4 weeks = 1080L/month
    assert_equal 1080, litres
    assert_equal 1080, result.litres
    assert_in_delta(quotation.ongoing_monthly_rate / 1080, result.rate, 0.01)
  end

  test "event quotes and quotes without volume data have no badge" do
    assert_nil RandsPerLitre.for(build_quotation(quote_type: "event", event_date: Date.today + 7))
    assert_nil RandsPerLitre.for(build_quotation)
  end

  # --- pill states (cost floor comparison) ---

  def build_cost_model(**attrs)
    CostModel.create!({
      founder_salary: 1000, driver_salary: 0,
      depreciation: 0, maintenance: 0, hosting: 0, data_comms: 0, bank_fees: 0, licence: 0,
      fuel_per_route_day: 0, route_days_per_month: 0, marketing: 0, supplies: 0, other: 0,
      num_bakkies: 1, target_monthly_litres: 18, minimum_margin_pct: 0.25
    }.merge(attrs))
    # monthly_total is 1000, target 18L → floor_target R55.56/L, price_guidance R69.44/L
  end

  test "state is green when rate is at or above price_guidance" do
    build_cost_model
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: 1300.0) # R72.22/L

    assert_equal :green, RandsPerLitre.for(sub).state
  end

  test "state is amber when rate is between floor_target and price_guidance" do
    build_cost_model
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: 1100.0) # R61.11/L

    assert_equal :amber, RandsPerLitre.for(sub).state
  end

  test "state is red when rate is below floor_target" do
    build_cost_model
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0) # R12.22/L

    assert_equal :red, RandsPerLitre.for(sub).state
  end

  test "state is nil when the cost model has no target_monthly_litres set" do
    build_cost_model(target_monthly_litres: 0)
    sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0)

    result = RandsPerLitre.for(sub)
    assert_nil result.state
    assert_nil result.floor_target
  end

  # --- realised_r_per_litre ---

  test "realised_r_per_litre compares actual revenue to actual litres over the last 3 complete months" do
    travel_to Date.new(2026, 7, 19) do
      sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0, start_date: Date.new(2026, 1, 1))
      # 3 complete months (Apr, May, Jun) x 3 bags x 5L = 15L each = 45L total
      [Date.new(2026, 4, 15), Date.new(2026, 5, 15), Date.new(2026, 6, 15)].each do |date|
        sub.collections.create!(date: date, bags: 3, skip: false)
      end

      result = RandsPerLitre.for(sub)
      # (220 * 3) / 45 = R14.67/L
      assert_in_delta 14.67, result.realised_rate, 0.01
    end
  end

  test "realised_r_per_litre is nil for a subscription that started mid-window" do
    travel_to Date.new(2026, 7, 19) do
      sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0, start_date: Date.new(2026, 5, 1))
      sub.collections.create!(date: Date.new(2026, 6, 15), bags: 3, skip: false)

      assert_nil RandsPerLitre.for(sub).realised_rate
    end
  end

  test "realised_r_per_litre is nil when there's no real litres in the window" do
    travel_to Date.new(2026, 7, 19) do
      sub = build_subscription(plan: "Standard", monthly_subscription_amount: 220.0, start_date: Date.new(2026, 1, 1))

      assert_nil RandsPerLitre.for(sub).realised_rate
    end
  end
end
