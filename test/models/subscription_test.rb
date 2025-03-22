require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      first_name: "Test",
      last_name: "User",
      email: "user@example.com",
      phone_number: "+27836353126",
      password: "password",
      referral_code: "REF123"
    )

    @old_sub = Subscription.create!(
      user: @user,
      plan: "Standard",
      duration: 1,
      start_date: Date.new(2025, 2, 1),
      end_date: Date.new(2025, 2, 28),
      status: :completed
    )
  end

  test "suggested start date is payment date when no collections happened" do
    payment_date = Date.new(2025, 3, 21)

    new_sub = Subscription.new(user: @user)
    assert_equal payment_date, new_sub.suggested_start_date(payment_date: payment_date)
  end

  test "suggested start date continues from last end if collections match" do
    payment_date = Date.new(2025, 3, 21)

    # Simulate weekly collections after last end
    [3, 10, 17].each do |day_offset|
      Collection.create!(
        subscription: @old_sub,
        date: Date.new(2025, 3, day_offset)
      )
    end

    new_sub = Subscription.new(user: @user)
    assert_equal @old_sub.end_date + 1.day, new_sub.suggested_start_date(payment_date: payment_date)
  end

  test "suggested start date is payment date if too few collections" do
    payment_date = Date.new(2025, 3, 21)

    # Only one collection
    Collection.create!(
      subscription: @old_sub,
      date: Date.new(2025, 3, 5)
    )

    new_sub = Subscription.new(user: @user)
    assert_equal payment_date, new_sub.suggested_start_date(payment_date: payment_date)
  end
end
