# frozen_string_literal: true
require "test_helper"

class CollectionSegmentTest < ActiveSupport::TestCase
  def make_user
    User.create!(
      first_name: "Seg", last_name: "Ment",
      phone_number: "+2782#{rand(1_000_000..9_999_999)}", password: "password",
      email: "seg-#{SecureRandom.hex(4)}@gmail.com", og: false
    )
  end

  def subscription(plan: "Standard", user: make_user)
    attrs = {
      user: user, street_address: "1 Test Rd, Rondebosch", suburb: "Rondebosch",
      collection_day: "Tuesday", plan: plan, duration: (plan == "once_off" ? nil : 3),
      status: :active, start_date: Date.current - 2.weeks, latitude: -33.96, longitude: 18.48
    }
    attrs.merge!(bucket_size: 25, buckets_per_collection: 2) if plan == "Commercial"
    Subscription.create!(attrs)
  end

  def upcoming(sub)
    Collection.create!(subscription: sub, date: Date.current + 2.days, bags: 0, buckets: 0.0, skip: false)
  end

  def past(sub, count)
    count.times { |i| Collection.create!(subscription: sub, date: Date.current - (i + 1).weeks, bags: 0, buckets: 0.0, skip: false) }
  end

  def segment_of(collection)
    CollectionSegment.for_collections([collection])[collection.id]
  end

  test "commercial plan is the commercial segment even when brand new" do
    sub = subscription(plan: "Commercial")
    assert_equal :commercial, segment_of(upcoming(sub))
  end

  test "once-off plan is the once_off segment" do
    sub = subscription(plan: "once_off")
    assert_equal :once_off, segment_of(upcoming(sub))
  end

  test "a Standard customer with no history is a new_customer" do
    sub = subscription(plan: "Standard")
    assert_equal :new_customer, segment_of(upcoming(sub))
  end

  test "a Standard customer with one past collection is still new_customer" do
    sub = subscription(plan: "Standard")
    past(sub, 1)
    assert_equal :new_customer, segment_of(upcoming(sub))
  end

  test "a Standard customer with a history is standard" do
    sub = subscription(plan: "Standard")
    past(sub, 2)
    assert_equal :standard, segment_of(upcoming(sub))
  end

  test "an XL customer with a history is standard" do
    sub = subscription(plan: "XL")
    past(sub, 2)
    assert_equal :standard, segment_of(upcoming(sub))
  end

  test "newness is judged per user across subscriptions" do
    user = make_user
    old_sub = subscription(plan: "Standard", user: user)
    past(old_sub, 3)
    new_sub = subscription(plan: "Standard", user: user)
    assert_equal :standard, segment_of(upcoming(new_sub)), "a veteran's new subscription is not new"
  end
end
