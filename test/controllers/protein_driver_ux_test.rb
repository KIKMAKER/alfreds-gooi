# frozen_string_literal: true
require "test_helper"

# Alfred has to know, at a glance, which stops are protein — he must load sealed
# swap buckets before leaving. And when he logs a drop, he has to be able to say
# which stream it was.
class ProteinDriverUxTest < ActionDispatch::IntegrationTest
  setup do
    @driver = User.create!(
      first_name: "Alfred", last_name: "Driver",
      phone_number: "+2782111#{rand(1000..9999)}", password: "password",
      email: "driver-#{SecureRandom.hex(3)}@gmail.com",
      role: :driver
    )

    @customer = User.create!(
      first_name: "Nina", last_name: "Restaurateur",
      phone_number: "+2782222#{rand(1000..9999)}", password: "password",
      email: "nina-#{SecureRandom.hex(3)}@gmail.com"
    )

    @protein_sub = Subscription.create!(
      user: @customer, plan: "Commercial", waste_stream: :protein,
      collections_per_week: 3, duration: 6,
      street_address: "18 Kloof Street, Gardens", suburb: "Gardens",
      bucket_size: 25, buckets_per_collection: 2, title: "Nina's Kitchen",
      status: :active
    )

    @date        = Date.new(2026, 7, 8)
    @drivers_day = DriversDay.create!(date: @date, user: @driver)
    @collection  = Collection.create!(subscription: @protein_sub, drivers_day: @drivers_day, date: @date)

    @langa = DropOffSite.create!(
      name: "Langa AgriHub", street_address: "Washington Street, Langa", suburb: "Langa",
      collection_day: "Wednesday", accepts_protein: true, fee_per_kg: 0.50
    )
    @sfl = DropOffSite.create!(
      name: "Soil for Life", street_address: "Rosemead Avenue, Constantia", suburb: "Constantia",
      collection_day: "Wednesday", fee_per_kg: 0
    )

    sign_in @driver
  end

  test "the collections list badges protein stops" do
    get collections_drivers_day_path(@drivers_day)

    assert_response :success
    assert_select ".dd-collection-badge--protein", minimum: 1
    assert_match(/Sealed swap buckets/, response.body)
  end

  test "the drop-off form lets the driver pick the stream at a protein site" do
    event = DropOffEvent.create!(drop_off_site: @langa, drivers_day: @drivers_day, date: @date,
                                 waste_stream: @langa.default_waste_stream)

    get edit_drivers_day_drop_off_event_path(@drivers_day, event)

    assert_response :success
    assert_select "input[name='drop_off_event[waste_stream]'][value=protein]", count: 1
    assert_select "input[name='drop_off_event[waste_stream]'][value=general]", count: 1
  end

  test "the drop-off form offers no stream choice at a site that cannot take protein" do
    event = DropOffEvent.create!(drop_off_site: @sfl, drivers_day: @drivers_day, date: @date)

    get edit_drivers_day_drop_off_event_path(@drivers_day, event)

    assert_response :success
    assert_select "input[name='drop_off_event[waste_stream]']", count: 0
    assert_match(/does not accept protein/, response.body)
  end

  test "the driver can switch a drop back to general at a protein site" do
    event = DropOffEvent.create!(drop_off_site: @langa, drivers_day: @drivers_day, date: @date,
                                 waste_stream: :protein)

    patch drivers_day_drop_off_event_path(@drivers_day, event),
          params: { drop_off_event: { waste_stream: "general" } }

    assert event.reload.general_waste_stream?
  end
end
