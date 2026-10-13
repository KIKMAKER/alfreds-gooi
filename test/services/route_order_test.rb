require "test_helper"

class RouteOrderTest < ActiveSupport::TestCase
  setup do
    @alfred = User.create!(
      first_name: "Alfred", last_name: "Gooi",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", og: false, role: :driver
    )
    @day      = Date.current
    @today    = DriversDay.create!(user: @alfred, date: @day)
    @next_day = DriversDay.create!(user: @alfred, date: @day + 7)

    @subs = %w[Anna Ben Cara Dee].map { |name| subscription_for(name) }
    @site = DropOffSite.create!(
      name: "Neighbourhood Farm", street_address: "1 Farm Rd, Observatory",
      suburb: suburb_fixture("Observatory"), collection_day: "Thursday", fee_per_kg: 0
    )

    @todays_collections = @subs.map { |s| collection_on(@today, s, @day) }
    @drop_off = @today.drop_off_events.create!(drop_off_site: @site, date: @day,
                                               waste_stream: @site.default_waste_stream)
    @next_collections = @subs.map { |s| collection_on(@next_day, s, @day + 7) }
    @next_drop_off = @next_day.drop_off_events.create!(drop_off_site: @site, date: @day + 7,
                                                       waste_stream: @site.default_waste_stream)
  end

  # Order the driver wants: Cara, Anna, DROP-OFF, Dee, Ben
  def dragged_order
    c = @todays_collections
    [c[2], c[0], @drop_off, c[3], c[1]].map do |item|
      { type: item.is_a?(DropOffEvent) ? "drop_off_event" : "collection", id: item.id }
    end
  end

  def sub_names(day)
    day.route_items.map { |i| i.is_a?(DropOffEvent) ? "DROP-OFF" : i.subscription.user.first_name }
  end

  test "save! persists the dragged order, interleaving drop-offs" do
    RouteOrder.save!(@today, dragged_order)

    assert_equal %w[Cara Anna DROP-OFF Dee Ben], sub_names(@today.reload)
    assert_equal [1, 2, 3, 4, 5], @today.route_items.map(&:position)
  end

  test "save! carries the order, including the drop-off, onto next week" do
    RouteOrder.save!(@today, dragged_order)

    assert_equal %w[Cara Anna DROP-OFF Dee Ben], sub_names(@next_day.reload)
    assert_equal [1, 2, 3, 4, 5], @next_day.route_items.map(&:position)
  end

  test "save! stores each subscription's slot without running validations" do
    # An invalid legacy subscription used to silently veto its own collection_order.
    @subs[1].update_column(:duration, nil)
    assert_not @subs[1].reload.valid?

    RouteOrder.save!(@today, dragged_order)

    # Rank among collections only: Cara 1, Anna 2, Dee 3, Ben 4
    assert_equal [2, 4, 1, 3], @subs.map { |s| s.reload.collection_order }
  end

  test "save! does not flatten next week via the subscription callback" do
    RouteOrder.save!(@today, dragged_order)

    # sync_collection_positions would have given Dee position 3 (collections-only)
    # and collided with the drop-off at 3.
    assert_equal 4, @next_collections[3].reload.position
    assert_equal 3, @next_drop_off.reload.position
  end

  test "stops on the day that were not submitted keep their order at the end" do
    late = collection_on(@today, subscription_for("Eli"), @day)
    @todays_collections.each_with_index { |c, i| c.update_column(:position, i + 1) }
    late.update_column(:position, nil)

    RouteOrder.save!(@today, dragged_order)

    assert_equal "Eli", @today.reload.route_items.last.subscription.user.first_name
    assert_equal [1, 2, 3, 4, 5, 6], @today.route_items.map(&:position)
  end

  test "ids from another day or unknown types are ignored" do
    foreign = @next_collections.first
    junk = [{ type: "collection", id: foreign.id }, { type: "nonsense", id: 1 }, { type: "collection", id: 0 }]

    assert_nothing_raised { RouteOrder.save!(@today, junk + dragged_order) }
    assert_equal %w[Cara Anna DROP-OFF Dee Ben], sub_names(@today.reload)
  end

  test "carry_forward! keeps a drop-off anchored to its customer when someone leaves" do
    RouteOrder.save!(@today, dragged_order)
    @next_collections[0].destroy # Anna leaves next week; the drop-off was after Anna

    RouteOrder.carry_forward!(@today, @next_day)

    # Anchor falls back to the nearest surviving earlier customer: Cara.
    assert_equal %w[Cara DROP-OFF Dee Ben], sub_names(@next_day.reload)
  end

  test "carry_forward! puts new customers and new sites at the end" do
    RouteOrder.save!(@today, dragged_order)
    newbie = collection_on(@next_day, subscription_for("Fay"), @day + 7)
    other_site = DropOffSite.create!(
      name: "Other Farm", street_address: "2 Farm Rd, Observatory",
      suburb: suburb_fixture("Observatory"), collection_day: "Thursday", fee_per_kg: 0
    )
    @next_day.drop_off_events.create!(drop_off_site: other_site, date: @day + 7,
                                      waste_stream: other_site.default_waste_stream)

    RouteOrder.carry_forward!(@today, @next_day)

    names = sub_names(@next_day.reload)
    assert_equal %w[Cara Anna DROP-OFF Dee Ben], names.first(5)
    assert_equal ["Fay", "DROP-OFF"], names.last(2)
    assert newbie.reload.position > 5
  end

  test "next_week_day finds the same weekday a week on, nil when not created yet" do
    assert_equal @next_day, RouteOrder.next_week_day(@today)
    assert_nil RouteOrder.next_week_day(@next_day)
  end

  test "save! with no next week yet still saves today" do
    DropOffEvent.where(drivers_day: @next_day).delete_all
    Collection.where(drivers_day: @next_day).delete_all
    @next_day.destroy

    RouteOrder.save!(@today, dragged_order)

    assert_equal %w[Cara Anna DROP-OFF Dee Ben], sub_names(@today.reload)
  end

  private

  def subscription_for(name)
    user = User.create!(
      first_name: name, last_name: "Tester",
      phone_number: "+2782#{rand(1_000_000..9_999_999)}", password: "password",
      email: "#{name.downcase}-#{SecureRandom.hex(3)}@gmail.com", og: false
    )
    Subscription.create!(
      user: user, street_address: "12 #{name} Rd, Rondebosch",
      suburb: suburb_fixture("Rondebosch"), collection_day: Date::DAYNAMES[Date.current.wday],
      plan: "Standard", duration: 3, status: :active,
      start_date: Date.current - 1.week, latitude: -33.96, longitude: 18.48
    )
  end

  def collection_on(drivers_day, subscription, date)
    Collection.create!(subscription: subscription, drivers_day: drivers_day, date: date,
                       bags: 0, buckets: 0.0, skip: false)
  end
end
