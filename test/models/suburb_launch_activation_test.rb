require "test_helper"

# Covers step 2 of the suburb launch mechanic: a subscription paid for while its
# suburb is on the pre-launch waitlist stays pending, with a start_date computed
# near the suburb's launch_date, until Suburb#go_live! finalizes it.
class SuburbLaunchActivationTest < ActiveSupport::TestCase
  def build_paid_pending_subscription(suburb, collection_day: "Tuesday")
    user = User.create!(
      first_name: "Launch", last_name: "Test",
      email: "launch_activation_#{SecureRandom.hex(4)}@example.com",
      phone_number: "+2783#{rand(1_000_000..9_999_999)}", password: "password"
    )
    sub = Subscription.create!(
      user: user, plan: "Standard", duration: 1, suburb: suburb,
      street_address: "1 Launch Street", status: :pending, collection_day: collection_day
    )
    Invoice.create!(subscription: sub, paid: true, total_amount: 220, issued_date: Date.current, due_date: Date.current + 14)
    sub
  end

  test "activate_subscription leaves a waitlist-suburb subscription pending" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)

    sub.activate_subscription

    assert sub.reload.pending?
  end

  test "activate_subscription sets start_date near launch_date - 1.week, aligned to collection_day" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)

    sub.activate_subscription
    sub.reload

    assert_equal "Tuesday", sub.start_date.strftime("%A")
    assert sub.start_date.to_date <= suburb.launch_date, "start_date should land on/before launch_date"
    assert sub.start_date.to_date > suburb.launch_date - 2.weeks, "start_date shouldn't be more than ~a week early"
  end

  test "activate_subscription clamps start_date forward when paid on/after launch_date (suburb still waitlist)" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current, collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)

    sub.activate_subscription
    sub.reload

    assert sub.pending?, "still deferred — suburb hasn't been manually flipped live"
    assert sub.start_date.to_date >= Date.current, "start_date must never land in the past"
  end

  test "activate_subscription activates normally for a non-waitlist suburb" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)

    sub.activate_subscription

    assert sub.reload.active?
  end

  test "finalize_deferred_activation! flips status without touching start_date" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)
    sub.activate_subscription
    sub.reload
    deferred_start_date = sub.start_date

    sub.finalize_deferred_activation!

    assert sub.reload.active?
    assert_equal deferred_start_date, sub.start_date
  end

  test "Suburb#go_live! finalizes paid pending subscriptions in that suburb" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)
    sub.activate_subscription

    suburb.go_live!

    assert sub.reload.active?
  end

  test "finalize_deferred_activation! heals a subscription whose collection_day never got set" do
    # Reproduces a real bug: a subscription created before the suburb's own
    # collection_day was finalized stays stuck with collection_day nil forever
    # (set_collection_day only fires once, when suburb_id is first assigned).
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)
    sub.update_column(:collection_day, nil)

    sub.finalize_deferred_activation!

    assert_equal "Tuesday", sub.reload.collection_day
  end

  test "Suburb#go_live! does not abort the whole batch when one subscription's first collection fails" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    broken_sub = build_paid_pending_subscription(suburb)
    healthy_sub = build_paid_pending_subscription(suburb)

    call_count = 0
    CreateFirstCollectionJob.stub :perform_now, ->(subscription) {
      call_count += 1
      raise "boom" if subscription.id == broken_sub.id
    } do
      suburb.go_live!
    end

    assert_equal 2, call_count
    assert healthy_sub.reload.active?
  end

  test "activate_subscription returns false when deferred, true when it actually activates" do
    waitlist_suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    deferred_sub = build_paid_pending_subscription(waitlist_suburb)
    assert_equal false, deferred_sub.activate_subscription

    active_suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    activated_sub = build_paid_pending_subscription(active_suburb)
    assert_equal true, activated_sub.activate_subscription
  end

  test "a deferred subscription does not get a first collection created at payment time" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)

    assert_no_difference "Collection.count" do
      sub.activate_subscription
    end
  end

  test "Suburb#go_live! creates the first collection for each finalized subscription" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    sub = build_paid_pending_subscription(suburb)
    sub.activate_subscription

    assert_difference "Collection.where(subscription: sub).count", 1 do
      suburb.go_live!
    end
  end

  test "Suburb#go_live! does not activate a pending subscription with no paid invoice" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    user = User.create!(first_name: "Unpaid", last_name: "Test", email: "launch_unpaid_#{SecureRandom.hex(4)}@example.com", phone_number: "+2783#{rand(1_000_000..9_999_999)}", password: "password")
    unpaid_sub = Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Launch Street", status: :pending, collection_day: "Tuesday")

    suburb.go_live!

    assert unpaid_sub.reload.pending?
  end

  test "active_subs_for excludes a deferred (pending, paid) subscription on its collection day" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    deferred_sub = build_paid_pending_subscription(suburb)
    deferred_sub.activate_subscription # stays pending — suburb is still waitlist

    assert_not_includes Subscription.active_subs_for("Tuesday"), deferred_sub
  end

  test "active_subs_for includes an active subscription on its collection day" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    user = User.create!(first_name: "Active", last_name: "Test", email: "launch_active_#{SecureRandom.hex(4)}@example.com", phone_number: "+2783#{rand(1_000_000..9_999_999)}", password: "password")
    sub = Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Test Street", status: :active, collection_day: "Tuesday")

    assert_includes Subscription.active_subs_for("Tuesday"), sub
  end
end
