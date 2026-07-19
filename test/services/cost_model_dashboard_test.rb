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

  def build_collection(date:, bags:)
    user = User.create!(
      first_name: "Test", last_name: "Customer", email: "cmd-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    sub = Subscription.create!(
      user: user, plan: "Standard", duration: 3,
      street_address: "1 Test St", suburb: "Claremont"
    )
    Collection.create!(subscription: sub, date: date, bags: bags, skip: false)
  end

  test "burn_gap is mrr minus monthly_total" do
    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 1500.0)
    assert_equal 500.0, dashboard.burn_gap

    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 400.0)
    assert_equal(-600.0, dashboard.burn_gap)
  end

  test "current_avg_rate blends mrr over real trailing-3mo litres" do
    travel_to Date.new(2026, 7, 19) do
      build_collection(date: Date.new(2026, 6, 25), bags: 20) # 100L, within the last 3 complete months

      dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 500.0)

      # 100L over 3 months → avg 33.3L/mo → R500 / 33.3 ≈ R15.02/L
      assert_in_delta 15.02, dashboard.current_avg_rate, 0.1
    end
  end

  test "current_avg_rate and litres_needed_to_break_even are nil with no real litres" do
    dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 500.0)
    assert_nil dashboard.current_avg_rate
    assert_nil dashboard.litres_needed_to_break_even
  end

  test "litres_needed_to_break_even divides monthly_total by current_avg_rate" do
    travel_to Date.new(2026, 7, 19) do
      build_collection(date: Date.new(2026, 6, 25), bags: 20) # 100L

      dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 500.0)
      expected = (dashboard.monthly_total / dashboard.current_avg_rate).round(1)

      assert_equal expected, dashboard.litres_needed_to_break_even
    end
  end

  test "monthly_litres_trend returns oldest-first litres for the last 3 complete months, excluding this month" do
    travel_to Date.new(2026, 7, 19) do
      build_collection(date: Date.new(2026, 4, 5), bags: 10)  # 50L, oldest complete month
      build_collection(date: Date.new(2026, 7, 10), bags: 99) # this month — must not appear

      dashboard = CostModelDashboard.new(cost_model: build_cost_model, mrr: 0)
      trend = dashboard.monthly_litres_trend(3)

      assert_equal 3, trend.size
      assert_equal ["Apr 2026", "May 2026", "Jun 2026"], trend.map(&:label)
      assert_equal 50, trend.first.litres
      assert_equal 0, trend.last.litres
    end
  end
end
