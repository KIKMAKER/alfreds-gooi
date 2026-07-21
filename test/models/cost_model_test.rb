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

  def build_collection(date:, bags:, skip: false)
    user = User.create!(
      first_name: "Test", last_name: "Customer", email: "cost.model.test-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
    subscription = Subscription.create!(
      user: user, plan: "Standard", duration: 3,
      street_address: "1 Test Street", suburb: suburb_fixture("Claremont")
    )
    Collection.create!(subscription: subscription, date: date, bags: bags, skip: skip)
  end

  test "complete_months_range spans the 3 months strictly before as_of's month" do
    range = CostModel.complete_months_range(3, as_of: Date.new(2026, 7, 19))
    assert_equal Date.new(2026, 4, 1), range.first
    assert_equal Date.new(2026, 6, 30), range.last
  end

  test "floor_current divides monthly_total by the real average over the last 3 complete months" do
    travel_to Date.new(2026, 7, 19) do
      # 10 bags * 5L = 50L per collection, one in the oldest complete month, one in the most recent.
      build_collection(date: Date.new(2026, 4, 5), bags: 10)
      build_collection(date: Date.new(2026, 6, 25), bags: 10)
      # Skipped collections must not count towards real volume.
      build_collection(date: Date.new(2026, 6, 10), bags: 99, skip: true)
      # This month is still in progress — must not count towards the trailing average.
      build_collection(date: Date.new(2026, 7, 19), bags: 99)

      assert_in_delta(100.0 / 3, @cost_model.trailing_3mo_avg_litres, 0.1)
      assert_in_delta(43_898.0 / @cost_model.trailing_3mo_avg_litres, @cost_model.floor_current.to_f, 0.01)
    end
  end

  test "floor_current is nil when there is no real collection data in the last 3 complete months" do
    travel_to Date.new(2026, 7, 19) do
      # Only a current-month collection exists — doesn't count towards the trailing average.
      build_collection(date: Date.new(2026, 7, 19), bags: 10)

      assert_equal 0.0, @cost_model.trailing_3mo_avg_litres
      assert_nil @cost_model.floor_current
    end
  end

  test "month_to_date_litres sums only real collections from this month so far" do
    travel_to Date.new(2026, 7, 19) do
      build_collection(date: Date.new(2026, 7, 10), bags: 10) # 50L, this month
      build_collection(date: Date.new(2026, 6, 25), bags: 10) # 50L, last month — excluded

      assert_equal 50, @cost_model.month_to_date_litres
    end
  end

  test "month_to_date_projected_litres straight-line projects by day of month" do
    travel_to Date.new(2026, 7, 19) do # day 19 of a 31-day month
      build_collection(date: Date.new(2026, 7, 10), bags: 10) # 50L so far

      # 50L over 19 days -> 31 days = ~81.6L
      assert_in_delta 81.6, @cost_model.month_to_date_projected_litres, 0.1
    end
  end
end
