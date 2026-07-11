require "test_helper"

# One route day can drop general waste at one site and protein at another, so
# kilograms must stay separable by stream.
class DropOffEventStreamTest < ActiveSupport::TestCase
  def setup
    @driver = User.create!(
      email:        "driver-#{SecureRandom.hex(4)}@example.com",
      password:     "password",
      phone_number: "+27800000030",
      role:         :driver
    )

    @date = Date.new(2026, 7, 8)
    @drivers_day = DriversDay.create!(date: @date, user: @driver)

    @langa = DropOffSite.create!(
      name:            "Langa AgriHub",
      street_address:  "Washington Street, Langa",
      suburb:          "Langa",
      collection_day:  "Wednesday",
      accepts_protein: true,
      fee_per_kg:      0.50
    )

    @sfl = DropOffSite.create!(
      name:           "Soil for Life",
      street_address: "Rosemead Avenue, Constantia",
      suburb:         "Constantia",
      collection_day: "Wednesday",
      fee_per_kg:     0
    )
  end

  test "a mixed route day keeps protein and general kilograms separable" do
    DropOffEvent.create!(drop_off_site: @langa, drivers_day: @drivers_day, date: @date,
                         weight_kg: 40.0, is_done: true, waste_stream: :protein)
    DropOffEvent.create!(drop_off_site: @sfl, drivers_day: @drivers_day, date: @date,
                         weight_kg: 200.0, is_done: true, waste_stream: :general)

    events = @drivers_day.drop_off_events

    assert_equal 40.0,  events.protein.sum(:weight_kg)
    assert_equal 200.0, events.general.sum(:weight_kg)
    assert_equal 240.0, events.sum(:weight_kg), "total is still the full day"

    assert_equal({ kg: 40.0, fee: 20.0 }, @langa.fees_for(year: 2026, month: 7))
    assert_equal({ kg: 200.0, fee: 0.0 }, @sfl.fees_for(year: 2026, month: 7),
                 "Soil for Life is free — kilograms recorded, nothing owed")
  end

  test "events default to the general stream" do
    event = DropOffEvent.create!(drop_off_site: @sfl, drivers_day: @drivers_day, date: @date)

    assert event.general_waste_stream?
  end

  test "protein cannot be dropped at a site that does not accept it" do
    event = DropOffEvent.new(drop_off_site: @sfl, drivers_day: @drivers_day, date: @date,
                             waste_stream: :protein)

    assert_not event.valid?
    assert_match(/does not accept protein/, event.errors[:waste_stream].join)
  end
end
