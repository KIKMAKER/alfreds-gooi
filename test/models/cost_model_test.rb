require "test_helper"

class CostModelTest < ActiveSupport::TestCase
  def setup
    @cost_model = CostModel.create!(
      founder_salary: 20_000, driver_salary: 13_200,
      depreciation: 3235, maintenance: 667, hosting: 587,
      data_comms: 439, bank_fees: 278, licence: 200,
      fuel_per_route_day: 136, route_days_per_month: 22,
      marketing: 1500, supplies: 500, other: 300,
      num_bakkies: 1, target_monthly_litres: 2000, minimum_margin_pct: 0.25
    )
  end

  test "monthly_total reproduces the real cost structure" do
    assert_equal 43_898.0, @cost_model.monthly_total.to_f
  end

  test "monthly_total scales fixed costs by num_bakkies but not people or variable costs" do
    @cost_model.num_bakkies = 2
    # + one more fixed_per_bakkie_total (5406)
    assert_equal 49_304.0, @cost_model.monthly_total.to_f
  end

  test "floor_target divides monthly_total by the admin's target litres" do
    assert_in_delta(43_898.0 / 2000, @cost_model.floor_target.to_f, 0.01)
  end

  test "price_guidance adds the minimum margin on top of floor_target" do
    expected = @cost_model.floor_target * 1.25
    assert_in_delta expected.to_f, @cost_model.price_guidance.to_f, 0.01
  end

  test "floor_target is nil when no target litres are set" do
    @cost_model.target_monthly_litres = 0
    assert_nil @cost_model.floor_target
    assert_nil @cost_model.price_guidance
  end

  test "floor_current divides monthly_total by real trailing-3-month average litres" do
    user = User.create!(
      first_name: "Test", last_name: "Customer", email: "cost.model.test@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    subscription = Subscription.create!(
      user: user, plan: "Standard", duration: 3,
      street_address: "1 Test Street", suburb: "Claremont"
    )
    # 10 bags * 5L = 50L per collection, one collection a month back, one two months back.
    Collection.create!(subscription: subscription, date: 1.month.ago.to_date, bags: 10, is_done: true, skip: false)
    Collection.create!(subscription: subscription, date: 2.months.ago.to_date, bags: 10, is_done: true, skip: false)
    # Skipped and not-done collections must not count towards real volume.
    Collection.create!(subscription: subscription, date: 1.month.ago.to_date, bags: 99, is_done: false, skip: false)
    Collection.create!(subscription: subscription, date: 1.month.ago.to_date, bags: 99, is_done: true, skip: true)

    assert_in_delta 100.0, Collection.total_litres_between(3.months.ago.to_date, Date.current), 0.01
    assert_in_delta(100.0 / 3, @cost_model.trailing_3mo_avg_litres, 0.1)
    assert_in_delta(43_898.0 / @cost_model.trailing_3mo_avg_litres, @cost_model.floor_current.to_f, 0.01)
  end

  test "floor_current is nil when there is no real collection data" do
    assert_equal 0, Collection.total_litres_between(3.months.ago.to_date, Date.current)
    assert_nil @cost_model.floor_current
  end
end
