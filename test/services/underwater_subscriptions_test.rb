require "test_helper"

class UnderwaterSubscriptionsTest < ActiveSupport::TestCase
  def setup
    # monthly_total 1000, target 18L (Standard's expected monthly litres)
    # → floor_target R55.56/L, price_guidance R69.44/L
    CostModel.create!(
      founder_salary: 1000, driver_salary: 0,
      depreciation: 0, maintenance: 0, hosting: 0, data_comms: 0, bank_fees: 0, licence: 0,
      fuel_per_route_day: 0, route_days_per_month: 0, marketing: 0, supplies: 0, other: 0,
      num_bakkies: 1, target_monthly_litres: 18, minimum_margin_pct: 0.25
    )
  end

  def build_active_subscription(monthly_subscription_amount:, **attrs)
    user = User.create!(
      first_name: "Test", last_name: "Customer", email: "uws-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    Subscription.create!({
      user: user, plan: "Standard", duration: 1, status: :active,
      street_address: "1 Test St", suburb: suburb_fixture("Claremont"),
      monthly_subscription_amount: monthly_subscription_amount
    }.merge(attrs))
  end

  test "ranks active subscriptions by contracted_r_per_litre, cheapest first" do
    sub_red   = build_active_subscription(monthly_subscription_amount: 220.0)  # R12.22/L, red
    sub_green = build_active_subscription(monthly_subscription_amount: 1300.0) # R72.22/L, green

    rows = UnderwaterSubscriptions.call

    assert_equal [sub_red, sub_green], rows.map(&:subscription)
    assert_equal :red, rows.first.result.state
    assert_equal :green, rows.last.result.state
  end

  test "underwater returns only the red rows" do
    sub_red   = build_active_subscription(monthly_subscription_amount: 220.0)
    build_active_subscription(monthly_subscription_amount: 1300.0)

    underwater = UnderwaterSubscriptions.underwater

    assert_equal [sub_red], underwater.map(&:subscription)
  end

  test "the same rank appears identically for a brand-new sub and a long-running one on the same price" do
    old_sub = build_active_subscription(monthly_subscription_amount: 220.0, start_date: 2.years.ago)
    old_sub.collections.create!(date: 1.month.ago.to_date, bags: 4, skip: false)
    new_sub = build_active_subscription(monthly_subscription_amount: 220.0, start_date: 1.day.ago)

    rates = UnderwaterSubscriptions.call.map { |row| row.result.rate }
    assert_equal [rates.first], rates.uniq
    assert_equal 2, rates.size
  end

  test "skips subscriptions never billed (no cached monthly amount yet)" do
    build_active_subscription(monthly_subscription_amount: nil)

    assert_equal [], UnderwaterSubscriptions.call
  end

  test "skips satellite and non-active subscriptions" do
    primary = build_active_subscription(monthly_subscription_amount: 1300.0)
    build_active_subscription(monthly_subscription_amount: 0, primary_subscription: primary)
    build_active_subscription(monthly_subscription_amount: 1300.0, status: :pause)

    subs = UnderwaterSubscriptions.call.map(&:subscription)
    assert_equal [primary], subs
  end
end
