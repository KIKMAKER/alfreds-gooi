# frozen_string_literal: true
require "test_helper"

class CollectionsControllerTest < ActionController::TestCase
  tests CollectionsController

  setup do
    @driver = User.create!(
      first_name: "Alfred", last_name: "Gooi",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "driver-#{SecureRandom.hex(3)}@example.com", og: false,
      role: :driver
    )

    @subscription = Subscription.create!(
      user: @driver,
      street_address: "123 Demo St, Rondebosch",
      suburb: "Rondebosch",
      collection_day: "Tuesday",
      plan: "Standard",
      duration: 1,
      status: :active,
      start_date: Date.current - 1.week,
      latitude: -33.96, longitude: 18.48
    )

    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in @driver
  end

  # Reproduces the production 500 (NoMethodError: undefined method `update_column'
  # for nil). Moving a collection onto a day whose positions have a GAP made
  # sync_drivers_day_with_date assign position = MAX(position) + 1, which
  # overshot the collection count. move_to_position! then inserted past the end
  # of the array, padding it with nils that blew up on update_column.
  test "moving a collection to a day with gapped positions does not 500 and renormalises positions" do
    target_date = Date.current - 2.weeks
    target_day  = DriversDay.create!(user: @driver, date: target_date)

    # Existing collections with a deliberate gap: positions 1, 2, 5 (max 5, count 3).
    [1, 2, 5].each do |pos|
      Collection.create!(subscription: @subscription, drivers_day: target_day,
                         date: target_date, position: pos)
    end

    # The collection being moved lives on a different day.
    other_date = Date.current - 3.weeks
    other_day  = DriversDay.create!(user: @driver, date: other_date)
    moving = Collection.create!(subscription: @subscription, drivers_day: other_day,
                                date: other_date, position: 1)

    # Changing the date moves it onto target_day (position becomes MAX+1 = 6),
    # which then triggers move_to_position!(collection, 6) on a 3-item list.
    patch :update, params: {
      id: moving.id,
      collection: { date: target_date.to_s, subscription_id: @subscription.id }
    }

    assert_response :redirect
    moving.reload
    assert_equal target_day.id, moving.drivers_day_id, "collection should move to the target day"

    positions = target_day.collections.reload.pluck(:position).sort
    assert_equal [1, 2, 3, 4], positions, "positions should be renormalised with no gaps"
    assert_not_includes positions, nil, "no collection should be left with a nil position"
  end

end

# The "Dropped Off!" button on collections#edit is what ends new-customer status.
# It used to clear the flag with a plain `subscription.update`, which silently
# no-ops on any subscription that fails validation, and it never touched the
# next-week collection that CreateNextWeekCollectionsJob had already stamped.
class NewCustomerFlagTest < ActionController::TestCase
  tests CollectionsController

  setup do
    @driver = User.create!(
      first_name: "Alfred", last_name: "Gooi",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "driver-#{SecureRandom.hex(3)}@example.com", og: false,
      role: :driver
    )

    @subscription = Subscription.create!(
      user: @driver,
      street_address: "123 Demo St, Rondebosch",
      suburb: "Rondebosch",
      collection_day: "Tuesday",
      plan: "Standard",
      duration: 1,
      status: :active,
      is_new_customer: true,
      start_date: Date.current - 1.week,
      latitude: -33.96, longitude: 18.48
    )

    @today = Collection.create!(subscription: @subscription, date: Date.current,
                                bags: 0, buckets: 0.0, skip: false, new_customer: true)
    @next_week = Collection.create!(subscription: @subscription, date: Date.current + 1.week,
                                    bags: 0, buckets: 0.0, skip: false, new_customer: true)

    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in @driver
  end

  def drop_off!
    patch :update, params: { id: @today.id, collection: { buckets: 2, is_done: true } }
  end

  test "drop-off clears the flag on the subscription and on current and future collections" do
    drop_off!

    assert_equal false, @today.reload.new_customer
    assert_equal false, @next_week.reload.new_customer, "pre-created next week collection"
    assert_equal false, @subscription.reload.is_new_customer
  end

  test "drop-off clears the flag even when the subscription fails validation" do
    @subscription.update_column(:suburb, "Llandudno") # legacy suburb, no longer in SUBURBS
    assert_not @subscription.reload.valid?, "sanity: subscription should be invalid"

    drop_off!

    assert_equal false, @today.reload.new_customer
    assert_equal false, @next_week.reload.new_customer, "pre-created next week collection"
    assert_equal false, @subscription.reload.is_new_customer
  end

  test "drop-off leaves past collections flagged for historical snapshots" do
    past = Collection.create!(subscription: @subscription, date: Date.current - 3.weeks,
                              bags: 0, buckets: 0.0, skip: false, new_customer: true)

    drop_off!

    assert_equal true, past.reload.new_customer
  end
end
