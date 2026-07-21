require "test_helper"

class PlanVolumeTest < ActiveSupport::TestCase
  def build_subscription(plan:, **attrs)
    user = User.create!(
      email: "pv-#{SecureRandom.hex(4)}@example.com", password: "password",
      phone_number: "+27800000005"
    )
    defaults = { user: user, plan: plan, duration: 3, street_address: "1 Test St", suburb: suburb_fixture("Rondebosch"), status: :active }
    defaults.merge!(bucket_size: 45, buckets_per_collection: 2, collections_per_week: 1) if plan == "Commercial"
    Subscription.create!(defaults.merge(attrs))
  end

  test "Standard uses the seeded 18L/month average, independent of any config" do
    sub = build_subscription(plan: "Standard")
    assert_equal 18.0, PlanVolume.expected_monthly_litres(sub)
  end

  test "XL uses the seeded 62L/month average" do
    sub = build_subscription(plan: "XL")
    assert_equal 62.0, PlanVolume.expected_monthly_litres(sub)
  end

  test "Commercial derives litres from bucket size and collection frequency" do
    sub = build_subscription(plan: "Commercial", bucket_size: 25, buckets_per_collection: 4, collections_per_week: 3)
    # 4 x 25L x 3/week x 4 weeks = 1200L
    assert_equal 1200, PlanVolume.expected_monthly_litres(sub)
  end

  test "once_off has no expected monthly litres" do
    sub = build_subscription(plan: "once_off")
    assert_nil PlanVolume.expected_monthly_litres(sub)
  end

  test "satellite subscriptions' litres are added to the primary's" do
    primary = build_subscription(plan: "XL")
    build_subscription(plan: "XL", primary_subscription: primary)

    assert_equal 124.0, PlanVolume.expected_monthly_litres(primary)
  end
end
