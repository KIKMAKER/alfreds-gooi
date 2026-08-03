require "test_helper"

class Subscriptions::RenewalServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      first_name: "Test", last_name: "Renewal", email: "rs-#{SecureRandom.hex(4)}@gooi.test",
      phone_number: "+27821234567", password: "password"
    )
  end

  def build_subscription(**attrs)
    Subscription.create!({
      user: @user, plan: "Standard", duration: 1, status: :active,
      street_address: "1 Test St", suburb: suburb_fixture("Claremont")
    }.merge(attrs))
  end

  # Regression: the previous ordering picked whichever subscription had the
  # latest end_date, and end_date is only ever set by the weekly completion
  # job — never at creation. A live/recent subscription always has a nil
  # end_date, so an old legacy subscription (which genuinely finished, and so
  # has a real end_date) would incorrectly outrank it.
  test "duplicates the most recently created subscription, not the one with the latest end_date" do
    old_legacy = build_subscription(
      status: :legacy, street_address: "99 Old Rd", suburb: suburb_fixture("Muizenberg"),
      end_date: 2.years.ago, created_at: 2.years.ago
    )
    recent = build_subscription(
      status: :active, street_address: "42 New Ave", suburb: suburb_fixture("Claremont"),
      end_date: nil, created_at: 1.day.ago
    )

    result = Subscriptions::RenewalService.new(user: @user, new_params: { plan: "XL", duration: 3 }).call

    assert result.success?, result.error
    assert_equal recent.street_address, result.subscription.street_address
    assert_equal recent.suburb, result.subscription.suburb
    assert_not_equal old_legacy.street_address, result.subscription.street_address
  end

  test "resets end_date to nil on the new subscription regardless of the template's end_date" do
    build_subscription(status: :completed, end_date: 6.months.ago, created_at: 6.months.ago)

    result = Subscriptions::RenewalService.new(user: @user, new_params: { plan: "Standard", duration: 1 }).call

    assert result.success?, result.error
    assert_nil result.subscription.end_date
  end
end
