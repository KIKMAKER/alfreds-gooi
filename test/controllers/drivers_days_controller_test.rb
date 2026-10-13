# frozen_string_literal: true
require "test_helper"

class DriversDaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    # The start action looks the driver up by name.
    @alfred = User.create!(
      first_name: "Alfred", last_name: "Gooi",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", og: false,
      role: :driver
    )

    @customer = User.create!(
      first_name: "Thandi", last_name: "Mokoena",
      phone_number: "+2782111#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", og: false
    )

    @subscription = Subscription.create!(
      user: @customer,
      street_address: "12 Rouwkoop Rd, Rondebosch",
      suburb: suburb_fixture("Rondebosch"),
      collection_day: Date::DAYNAMES[Date.current.wday],
      plan: "Standard",
      duration: 3,
      status: :active,
      start_date: Date.current - 1.week,
      latitude: -33.96, longitude: 18.48
    )

    @drivers_day = DriversDay.create!(user: @alfred, date: Date.current)
    sign_in @alfred
  end

  test "start page lists compost bags to load when a customer has claimed one" do
    Collection.create!(subscription: @subscription, drivers_day: @drivers_day,
                       date: Date.current, bags: 0, buckets: 0.0, skip: false, soil_bag: 1)

    get start_drivers_day_path(@drivers_day)

    assert_response :success
    assert_match(/Load 1 compost bag for 1 house/, response.body)
    assert_match(/Rouwkoop/, response.body)
  end

  test "start page omits the compost card when nobody has claimed a bag" do
    Collection.create!(subscription: @subscription, drivers_day: @drivers_day,
                       date: Date.current, bags: 0, buckets: 0.0, skip: false, soil_bag: 0)

    get start_drivers_day_path(@drivers_day)

    assert_response :success
    assert_no_match(/compost bag/, response.body)
  end

  test "reorder persists the dragged order and answers 200 json" do
    second = Collection.create!(subscription: @subscription, drivers_day: @drivers_day,
                                date: Date.current, bags: 0, buckets: 0.0, skip: false)
    other_customer = User.create!(first_name: "Lerato", last_name: "Dlamini",
                                  phone_number: "+2782222#{rand(1000..9999)}", password: "password",
                                  email: "lerato-#{SecureRandom.hex(3)}@gmail.com", og: false)
    other_sub = Subscription.create!(user: other_customer, street_address: "3 Main Rd, Rondebosch",
                                     suburb: suburb_fixture("Rondebosch"), plan: "Standard", duration: 3,
                                     collection_day: Date::DAYNAMES[Date.current.wday], status: :active,
                                     start_date: Date.current - 1.week, latitude: -33.96, longitude: 18.48)
    third = Collection.create!(subscription: other_sub, drivers_day: @drivers_day,
                               date: Date.current, bags: 0, buckets: 0.0, skip: false)

    patch reorder_drivers_day_path(@drivers_day),
          params: { items: [{ type: "collection", id: third.id }, { type: "collection", id: second.id }] },
          as: :json

    assert_response :success
    assert_equal 2, response.parsed_body["saved"]
    assert_equal [third.id, second.id], @drivers_day.collections.where(id: [second.id, third.id]).order(:position).pluck(:id)
    assert_equal 1, third.reload.position
    assert_equal 1, other_sub.reload.collection_order
  end

  test "reorder answers 422 rather than silently succeeding when items is missing" do
    patch reorder_drivers_day_path(@drivers_day), params: {}, as: :json

    assert_response :unprocessable_entity
  end
end
