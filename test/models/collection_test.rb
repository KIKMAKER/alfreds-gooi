require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  def setup
    @driver = User.create!(
      first_name: "Alfred",
      last_name: "Driver",
      email: "alfred.driver@gooi.test",
      phone_number: "+27836353126",
      password: "password",
      role: :driver
    )

    @customer = User.create!(
      first_name: "Thandi",
      last_name: "Mokoena",
      email: "thandi.mokoena@gooi.test",
      phone_number: "+27821234567",
      password: "password"
    )

    @subscription = Subscription.create!(
      user: @customer,
      plan: "Standard",
      duration: 3,
      street_address: "12 Palmboom Road",
      suburb: "Claremont"
    )

    @tuesday = Date.new(2026, 7, 7)
    @wednesday = Date.new(2026, 7, 8)

    @old_day = DriversDay.create!(user: @driver, date: @tuesday)
    @collection = Collection.create!(
      subscription: @subscription,
      date: @tuesday,
      drivers_day: @old_day,
      position: 1
    )
  end

  test "editing the date moves the collection to the drivers day for the new date" do
    new_day = DriversDay.create!(user: @driver, date: @wednesday)

    @collection.update!(date: @wednesday)

    assert_equal new_day.id, @collection.drivers_day_id
  end

  test "editing the date creates a drivers day when none exists for the new date" do
    assert_difference -> { DriversDay.count }, 1 do
      @collection.update!(date: @wednesday)
    end

    assert_equal @wednesday, @collection.drivers_day.date
    assert_equal @driver.id, @collection.drivers_day.user_id
  end

  test "moved collection is appended to the end of the new day's route" do
    new_day = DriversDay.create!(user: @driver, date: @wednesday)
    Collection.create!(subscription: @subscription, date: @wednesday, drivers_day: new_day, position: 3)

    @collection.update!(date: @wednesday)

    assert_equal 4, @collection.position
  end

  test "an explicit drivers_day change in the same save is not overridden" do
    DriversDay.create!(user: @driver, date: @wednesday)
    thursday_day = DriversDay.create!(user: @driver, date: Date.new(2026, 7, 9))

    @collection.update!(date: @wednesday, drivers_day: thursday_day)

    assert_equal thursday_day.id, @collection.drivers_day_id
  end

  test "an explicit position in the same save is kept" do
    new_day = DriversDay.create!(user: @driver, date: @wednesday)
    Collection.create!(subscription: @subscription, date: @wednesday, drivers_day: new_day, position: 3)

    @collection.update!(date: @wednesday, position: 2)

    assert_equal new_day.id, @collection.drivers_day_id
    assert_equal 2, @collection.position
  end

  test "creating a collection does not override an explicitly assigned drivers_day" do
    collection = Collection.create!(
      subscription: @subscription,
      date: @wednesday,
      drivers_day: @old_day
    )

    assert_equal @old_day.id, collection.drivers_day_id
  end

  test "date edit clears the drivers_day when no driver user exists" do
    @driver.update!(role: :customer)

    @collection.update!(date: @wednesday)

    assert_nil @collection.drivers_day_id
  end

  test "saving without a date change leaves the drivers_day alone" do
    other_day = DriversDay.create!(user: @driver, date: @wednesday)
    @collection.update!(drivers_day: other_day)

    @collection.update!(bags: 2)

    assert_equal other_day.id, @collection.drivers_day_id
  end
end
