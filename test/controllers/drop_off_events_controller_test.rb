# frozen_string_literal: true
require "test_helper"

class DropOffEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alfred = User.create!(
      first_name: "Alfred", last_name: "Gooi",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", og: false,
      role: :driver
    )

    @drivers_day = DriversDay.create!(user: @alfred, date: Date.current)

    @drop_off_site = DropOffSite.create!(
      name: "Neighbourhood Farm",
      street_address: "1 Farm Rd, Observatory",
      suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday",
      fee_per_kg: 0
    )

    sign_in @alfred
  end

  test "new lists drop-off sites not already on today's route" do
    get new_drivers_day_drop_off_event_path(@drivers_day)

    assert_response :success
    assert_match(/Neighbourhood Farm/, response.body)
  end

  test "new omits sites already added to today's route" do
    @drivers_day.drop_off_events.create!(drop_off_site: @drop_off_site, date: @drivers_day.date,
                                          waste_stream: @drop_off_site.default_waste_stream)

    get new_drivers_day_drop_off_event_path(@drivers_day)

    assert_response :success
    assert_no_match(/Neighbourhood Farm/, response.body)
  end

  test "create adds the site to today's drop-offs and redirects" do
    assert_difference "@drivers_day.drop_off_events.count", 1 do
      post drivers_day_drop_off_events_path(@drivers_day, drop_off_site_id: @drop_off_site.id)
    end

    assert_redirected_to drivers_day_drop_off_events_path(@drivers_day)
    event = @drivers_day.drop_off_events.last
    assert_equal @drop_off_site, event.drop_off_site
    assert_equal @drivers_day.date, event.date
  end

  test "create does not duplicate an event for a site already on the route" do
    @drivers_day.drop_off_events.create!(drop_off_site: @drop_off_site, date: @drivers_day.date,
                                          waste_stream: @drop_off_site.default_waste_stream)

    assert_no_difference "@drivers_day.drop_off_events.count" do
      post drivers_day_drop_off_events_path(@drivers_day, drop_off_site_id: @drop_off_site.id)
    end
  end
end
