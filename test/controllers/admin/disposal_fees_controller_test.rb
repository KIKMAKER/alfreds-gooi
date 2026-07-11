# frozen_string_literal: true
require "test_helper"

class Admin::DisposalFeesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Kiki", last_name: "Kennedy",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "admin-#{SecureRandom.hex(3)}@gmail.com",
      role: :admin
    )

    @driver = User.create!(
      first_name: "Alfred", last_name: "Driver",
      phone_number: "+2782111#{rand(1000..9999)}", password: "password",
      email: "driver-#{SecureRandom.hex(3)}@gmail.com",
      role: :driver
    )

    @langa = DropOffSite.create!(
      name: "Langa AgriHub", street_address: "Washington Street, Langa", suburb: "Langa",
      collection_day: "Wednesday", accepts_protein: true, fee_per_kg: 0.50
    )
    @sfl = DropOffSite.create!(
      name: "Soil for Life", street_address: "Rosemead Avenue, Constantia", suburb: "Constantia",
      collection_day: "Wednesday", fee_per_kg: 0
    )

    date = Date.new(2026, 7, 8)
    day  = DriversDay.create!(date: date, user: @driver)
    DropOffEvent.create!(drop_off_site: @langa, drivers_day: day, date: date,
                         weight_kg: 40.0, is_done: true, waste_stream: :protein)
    DropOffEvent.create!(drop_off_site: @sfl, drivers_day: day, date: date,
                         weight_kg: 200.0, is_done: true, waste_stream: :general)

    sign_in @admin
  end

  test "lists charging sites with the fee owed and excludes free sites" do
    get admin_disposal_fees_path

    assert_response :success
    assert_match "Langa AgriHub", response.body
    assert_match "July 2026", response.body
    assert_match "20.00", response.body, "40kg × R0.50 = R20.00 owed"
    assert_no_match(/Soil for Life/, response.body, "free sites owe nothing and are not listed")
  end
end
