require "test_helper"

class DisposalFeesReportTest < ActiveSupport::TestCase
  def setup
    @driver = User.create!(
      email:        "driver-#{SecureRandom.hex(4)}@example.com",
      password:     "password",
      phone_number: "+27800000040",
      role:         :driver
    )

    @langa = DropOffSite.create!(
      name: "Langa AgriHub", street_address: "Washington Street, Langa", suburb: "Langa",
      collection_day: "Wednesday", accepts_protein: true, fee_per_kg: 0.50
    )
    @streetscapes = DropOffSite.create!(
      name: "Streetscapes", street_address: "Roeland Street, Gardens", suburb: "Gardens",
      collection_day: "Thursday", fee_per_kg: 0.30
    )
    @sfl = DropOffSite.create!(
      name: "Soil for Life", street_address: "Rosemead Avenue, Constantia", suburb: "Constantia",
      collection_day: "Wednesday", fee_per_kg: 0
    )
  end

  def drop(site:, kg:, date:, is_done: true)
    day = DriversDay.find_or_create_by!(date: date, user: @driver)
    DropOffEvent.create!(
      drop_off_site: site, drivers_day: day, date: date,
      weight_kg: kg, is_done: is_done, waste_stream: site.default_waste_stream
    )
  end

  test "summarises fees owed by site by month" do
    drop(site: @langa, kg: 40.0, date: Date.new(2026, 7, 8))
    drop(site: @langa, kg: 60.0, date: Date.new(2026, 7, 15))
    drop(site: @langa, kg: 20.0, date: Date.new(2026, 6, 10))

    rows = DisposalFeesReport.new.rows
    july = rows.find { |r| r.site == @langa && r.month == Date.new(2026, 7, 1) }
    june = rows.find { |r| r.site == @langa && r.month == Date.new(2026, 6, 1) }

    assert_equal 100.0, july.kg_dropped
    assert_equal 50.0,  july.fee_owed
    assert_equal 20.0,  june.kg_dropped
    assert_equal 10.0,  june.fee_owed
  end

  test "excludes free sites entirely" do
    drop(site: @sfl,   kg: 200.0, date: Date.new(2026, 7, 8))
    drop(site: @langa, kg: 40.0,  date: Date.new(2026, 7, 8))

    sites = DisposalFeesReport.new.rows.map(&:site)

    assert_includes     sites, @langa
    assert_not_includes sites, @sfl, "free sites owe nothing and must not be listed"
  end

  test "excludes drops that are not completed" do
    drop(site: @langa, kg: 40.0,  date: Date.new(2026, 7, 8))
    drop(site: @langa, kg: 500.0, date: Date.new(2026, 7, 9), is_done: false)

    row = DisposalFeesReport.new.rows.find { |r| r.site == @langa }

    assert_equal 40.0, row.kg_dropped
    assert_equal 20.0, row.fee_owed
  end

  test "totals across charging sites" do
    drop(site: @langa,        kg: 40.0,  date: Date.new(2026, 7, 8))  # R20.00
    drop(site: @streetscapes, kg: 100.0, date: Date.new(2026, 7, 9))  # R30.00
    drop(site: @sfl,          kg: 200.0, date: Date.new(2026, 7, 10)) # free

    assert_equal 50.0, DisposalFeesReport.new.total_owed
  end

  test "carries the site's rate onto each row" do
    drop(site: @langa, kg: 40.0, date: Date.new(2026, 7, 8))

    row = DisposalFeesReport.new.rows.first

    assert_equal "Langa AgriHub", row.site_name
    assert_equal 0.50, row.fee_per_kg.to_f
  end
end
