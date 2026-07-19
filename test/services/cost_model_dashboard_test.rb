require "test_helper"

class CostModelDashboardTest < ActiveSupport::TestCase
  def build_cost_model(**attrs)
    CostModel.create!({
      founder_salary: 1000, driver_salary: 0,
      depreciation: 0, maintenance: 0, hosting: 0, data_comms: 0, bank_fees: 0, licence: 0,
      fuel_per_route_day: 0, route_days_per_month: 0, marketing: 0, supplies: 0, other: 0,
      num_bakkies: 1, target_monthly_litres: 1000, minimum_margin_pct: 0.25
    }.merge(attrs)) # monthly_total = 1000
  end

  test "burn_gap is mrr minus monthly_total" do
    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 1500.0)
    assert_equal 500.0, dashboard.burn_gap

    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 400.0)
    assert_equal(-600.0, dashboard.burn_gap)
  end

  test "current_avg_rate blends mrr over real trailing-3mo litres" do
    user = User.create!(
      first_name: "Test", last_name: "Customer", email: "cmd-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    sub = Subscription.create!(
      user: user, plan: "Standard", duration: 3,
      street_address: "1 Test St", suburb: "Claremont"
    )
    Collection.create!(subscription: sub, date: 1.month.ago.to_date, bags: 20, is_done: true, skip: false) # 100L

    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 500.0)

    # 100L over 3 months → avg 33.3L/mo → R500 / 33.3 ≈ R15.02/L
    assert_in_delta 15.02, dashboard.current_avg_rate, 0.1
  end

  test "current_avg_rate and litres_needed_to_break_even are nil with no real litres" do
    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 500.0)
    assert_nil dashboard.current_avg_rate
    assert_nil dashboard.litres_needed_to_break_even
  end

  test "litres_needed_to_break_even divides monthly_total by current_avg_rate" do
    user = User.create!(
      first_name: "Test", last_name: "Customer", email: "cmd2-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    sub = Subscription.create!(
      user: user, plan: "Standard", duration: 3,
      street_address: "1 Test St", suburb: "Claremont"
    )
    Collection.create!(subscription: sub, date: 1.month.ago.to_date, bags: 20, is_done: true, skip: false) # 100L

    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 500.0)
    expected = (dashboard.monthly_total / dashboard.current_avg_rate).round(1)

    assert_equal expected, dashboard.litres_needed_to_break_even
  end

  test "monthly_litres_trend returns oldest-first per-calendar-month litres" do
    user = User.create!(
      first_name: "Test", last_name: "Customer", email: "cmd3-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    sub = Subscription.create!(
      user: user, plan: "Standard", duration: 3,
      street_address: "1 Test St", suburb: "Claremont"
    )
    Collection.create!(subscription: sub, date: 2.months.ago.beginning_of_month.to_date + 1.day,
                       bags: 10, is_done: true, skip: false) # 50L, oldest month

    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 0)
    trend = dashboard.monthly_litres_trend(3)

    assert_equal 3, trend.size
    assert_equal 2.months.ago.to_date.beginning_of_month.strftime("%b %Y"), trend.first.label
    assert_equal 50, trend.first.litres
    assert_equal Date.current.beginning_of_month.strftime("%b %Y"), trend.last.label
  end
end
