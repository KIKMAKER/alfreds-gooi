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
