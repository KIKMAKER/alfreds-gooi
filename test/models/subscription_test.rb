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

  test "should set start_date to previous sub's end_date if collections continued" do
    user = @user
    old_sub = @old_sub

    # Simulate weekly collections since end_date
    4.times do |i|
      Collection.create!(subscription: old_sub, date: old_sub.end_date + i.weeks)
    end

    payment_date = Time.current.to_date
    new_sub = Subscription.new(user: user, duration: 3)

    new_sub.start_date = new_sub.suggested_start_date(payment_date: payment_date)

    assert_equal (old_sub.end_date + 1.day), new_sub.start_date.to_date

  end

  # test "marks subscriptions complete after enough collections" do
  #   sub = subscriptions(:active) # Factory or fixture
  #   sub.update!(start_date: 6.weeks.ago, duration: 1)

  #   # Simulate 5 collections
  #   5.times do
  #     Collection.create!(subscription: sub, date: 1.week.ago, skip: false)
  #   end

  #   CheckSubscriptionsForCompletionJob.perform_now

  #   assert sub.reload.completed?
  # end

end
