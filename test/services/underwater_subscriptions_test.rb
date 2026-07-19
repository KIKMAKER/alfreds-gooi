require "test_helper"

class UnderwaterSubscriptionsTest < ActiveSupport::TestCase
  def setup
    # monthly_total 1000 → floor_target R1.00/L, price_guidance R1.25/L
    CostModel.create!(
      founder_salary: 1000, driver_salary: 0,
      depreciation: 0, maintenance: 0, hosting: 0, data_comms: 0, bank_fees: 0, licence: 0,
      fuel_per_route_day: 0, route_days_per_month: 0, marketing: 0, supplies: 0, other: 0,
      num_bakkies: 1, target_monthly_litres: 1000, minimum_margin_pct: 0.25
    )
  end

  def build_active_subscription(**attrs)
    user = User.create!(
      first_name: "Test", last_name: "Customer", email: "uws-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    Subscription.create!({
      user: user, plan: "Standard", duration: 1, status: :active,
      street_address: "1 Test St", suburb: "Claremont"
    }.merge(attrs))
  end

  def build_invoice(subscription:, total:)
    Invoice.create!(
      subscription: subscription, issued_date: Date.today, due_date: Date.today + 14,
      total_amount: total
    )
  end

  test "ranks active subscriptions by their most recent invoice's effective R/L, cheapest first" do
    sub_red   = build_active_subscription
    sub_green = build_active_subscription
    build_invoice(subscription: sub_red, total: 10.0)   # 4 weeks x 5L = 20L → R0.50/L (red)
    build_invoice(subscription: sub_green, total: 40.0) # 20L → R2.00/L (green)

    rows = UnderwaterSubscriptions.call

    assert_equal [sub_red, sub_green], rows.map(&:subscription)
    assert_equal :red, rows.first.result.state
    assert_equal :green, rows.last.result.state
  end

  test "underwater returns only the red rows" do
    sub_red   = build_active_subscription
    sub_green = build_active_subscription
    build_invoice(subscription: sub_red, total: 10.0)
    build_invoice(subscription: sub_green, total: 40.0)

    underwater = UnderwaterSubscriptions.underwater

    assert_equal [sub_red], underwater.map(&:subscription)
  end

  test "uses each subscription's most recent invoice, not its oldest" do
    sub = build_active_subscription
    build_invoice(subscription: sub, total: 10.0).update!(issued_date: 30.days.ago)
    recent = build_invoice(subscription: sub, total: 40.0)
    recent.update!(issued_date: Date.today)

    row = UnderwaterSubscriptions.call.first
    assert_equal recent, row.invoice
    assert_equal :green, row.result.state
  end

  test "skips subscriptions with no invoice yet" do
    build_active_subscription

    assert_equal [], UnderwaterSubscriptions.call
  end

  test "skips satellite and non-active subscriptions" do
    primary = build_active_subscription
    build_invoice(subscription: primary, total: 40.0)

    satellite = build_active_subscription(primary_subscription: primary)
    build_invoice(subscription: satellite, total: 40.0)

    paused = build_active_subscription(status: :pause)
    build_invoice(subscription: paused, total: 40.0)

    subs = UnderwaterSubscriptions.call.map(&:subscription)
    assert_equal [primary], subs
  end
end
