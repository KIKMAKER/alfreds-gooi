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

  test "sync_drivers_day_with_date assigns a new record to its date's route" do
    new_day = DriversDay.create!(user: @driver, date: @wednesday)
    Collection.create!(subscription: @subscription, date: @wednesday, drivers_day: new_day, position: 3)

    collection = Collection.new(subscription: @subscription, date: @wednesday)
    collection.sync_drivers_day_with_date
    collection.save!

    assert_equal new_day.id, collection.drivers_day_id
    assert_equal 4, collection.position
  end

  test "sync_drivers_day_with_date does nothing without a date" do
    collection = Collection.new(subscription: @subscription)

    collection.sync_drivers_day_with_date

    assert_nil collection.drivers_day
    assert_no_difference -> { DriversDay.count } do
      collection.sync_drivers_day_with_date
    end
  end

  test "saving without a date change leaves the drivers_day alone" do
    other_day = DriversDay.create!(user: @driver, date: @wednesday)
    @collection.update!(drivers_day: other_day)

    @collection.update!(bags: 2)

    assert_equal other_day.id, @collection.drivers_day_id
  end

  # ── Soil bag claim token ────────────────────────────────────────────────

  test "collections start with no soil bag token" do
    assert_nil @collection.soil_bag_token
  end

  test "minting produces a short code free of ambiguous glyphs" do
    token = @collection.ensure_soil_bag_token!

    assert_equal Collection::SOIL_BAG_TOKEN_LENGTH, token.length
    assert_match(/\A[a-hj-km-np-z2-9]+\z/, token, "no 0/1/i/l/o in the alphabet")
  end

  test "minting twice returns the same token" do
    first = @collection.ensure_soil_bag_token!
    second = @collection.reload.ensure_soil_bag_token!

    assert_equal first, second
  end

  test "minting does not touch other collection attributes" do
    original_position = @collection.position
    @collection.ensure_soil_bag_token!

    assert_equal original_position, @collection.reload.position
    assert_equal 0, @collection.soil_bag
  end

  test "tokens are unique across collections" do
    other = Collection.create!(subscription: @subscription, date: @wednesday)

    assert_not_equal @collection.ensure_soil_bag_token!, other.ensure_soil_bag_token!
  end

  test "the database rejects a duplicate token" do
    token = @collection.ensure_soil_bag_token!
    other = Collection.create!(subscription: @subscription, date: @wednesday)

    assert_raises(ActiveRecord::RecordNotUnique) do
      other.update_column(:soil_bag_token, token)
    end
  end

  test "many untokened collections coexist despite the unique index" do
    assert_nothing_raised do
      3.times { |i| Collection.create!(subscription: @subscription, date: @wednesday + i.days) }
    end
  end

  test "revoking clears only that collection's token" do
    other = Collection.create!(subscription: @subscription, date: @wednesday)
    other_token = other.ensure_soil_bag_token!
    @collection.ensure_soil_bag_token!

    @collection.revoke_soil_bag_token!

    assert_nil @collection.reload.soil_bag_token
    assert_equal other_token, other.reload.soil_bag_token
  end

  test "a link expires once its collection date has passed" do
    @collection.update_column(:date, Date.current - 1.day)
    assert @collection.soil_bag_link_expired?

    @collection.update_column(:date, Date.current)
    assert_not @collection.soil_bag_link_expired?
  end

  test "find_by_soil_bag_token! rejects a blank token rather than matching a null column" do
    assert_raises(ActiveRecord::RecordNotFound) { Collection.find_by_soil_bag_token!(nil) }
    assert_raises(ActiveRecord::RecordNotFound) { Collection.find_by_soil_bag_token!("") }
  end
end
