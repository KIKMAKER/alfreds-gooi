# frozen_string_literal: true
require "test_helper"

class CollectionSkipPolicyTest < ActiveSupport::TestCase
  def make_user
    User.create!(
      first_name: "Cust", last_name: "Omer",
      phone_number: "+2782#{rand(1_000_000..9_999_999)}", password: "password",
      email: "cust-#{SecureRandom.hex(4)}@gmail.com", og: false
    )
  end

  def make_subscription(user, plan: "Standard")
    attrs = {
      user: user, street_address: "1 Test Rd, Rondebosch", suburb: "Rondebosch",
      collection_day: "Tuesday", plan: plan, duration: (plan == "once_off" ? nil : 3),
      status: :active, start_date: Date.current - 2.weeks, latitude: -33.96, longitude: 18.48
    }
    attrs.merge!(bucket_size: 25, buckets_per_collection: 2) if plan == "Commercial"
    Subscription.create!(attrs)
  end

  # The upcoming collection every scenario is being messaged about.
  def upcoming_collection(subscription)
    Collection.create!(subscription: subscription, date: Date.current + 2.days,
                       bags: 0, buckets: 0.0, skip: false)
  end

  def past_collections(subscription, count)
    count.times do |i|
      Collection.create!(subscription: subscription, date: Date.current - (i + 1).weeks,
                         bags: 0, buckets: 0.0, skip: false)
    end
  end

  test "a returning standard customer is eligible" do
    sub = make_subscription(make_user)
    past_collections(sub, 3)
    upcoming = upcoming_collection(sub)

    assert_includes CollectionSkipPolicy.eligible_collection_ids([upcoming]), upcoming.id
  end

  test "a once-off customer is never eligible" do
    sub = make_subscription(make_user, plan: "once_off")
    past_collections(sub, 3) # even with history, once-off is out
    upcoming = upcoming_collection(sub)

    assert_not_includes CollectionSkipPolicy.eligible_collection_ids([upcoming]), upcoming.id
  end

  test "a commercial customer is never eligible even with a long history" do
    sub = make_subscription(make_user, plan: "Commercial")
    past_collections(sub, 5)
    upcoming = upcoming_collection(sub)

    assert_not_includes CollectionSkipPolicy.eligible_collection_ids([upcoming]), upcoming.id
  end

  test "a brand-new customer whose first collection is the upcoming one is not eligible" do
    sub = make_subscription(make_user)
    upcoming = upcoming_collection(sub) # no past collections at all

    assert_not_includes CollectionSkipPolicy.eligible_collection_ids([upcoming]), upcoming.id
  end

  test "a customer who has had exactly one collection is still new" do
    sub = make_subscription(make_user)
    past_collections(sub, 1)
    upcoming = upcoming_collection(sub)

    assert_not_includes CollectionSkipPolicy.eligible_collection_ids([upcoming]), upcoming.id
  end

  test "a customer becomes eligible once they have more than one past collection" do
    sub = make_subscription(make_user)
    past_collections(sub, 2)
    upcoming = upcoming_collection(sub)

    assert_includes CollectionSkipPolicy.eligible_collection_ids([upcoming]), upcoming.id
  end

  test "newness is judged per user across all their subscriptions" do
    user = make_user
    old_sub = make_subscription(user)
    past_collections(old_sub, 3)
    new_sub = make_subscription(user) # same user, second subscription
    upcoming = upcoming_collection(new_sub)

    # The user is a veteran overall, so even a fresh subscription is eligible.
    assert_includes CollectionSkipPolicy.eligible_collection_ids([upcoming]), upcoming.id
  end

  test "mixed batch returns only the eligible ids" do
    returning = upcoming_collection(make_subscription(make_user).tap { |s| past_collections(s, 3) })
    once_off  = upcoming_collection(make_subscription(make_user, plan: "once_off"))
    brand_new = upcoming_collection(make_subscription(make_user))

    eligible = CollectionSkipPolicy.eligible_collection_ids([returning, once_off, brand_new])

    assert_equal [returning.id].to_set, eligible
  end
end
