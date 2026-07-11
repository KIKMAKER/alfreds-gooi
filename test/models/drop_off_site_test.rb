require "test_helper"

# Covers per-site disposal fees. Fees are computed against the kilograms the driver
# already records on each drop-off event, so there is no new data entry for Alfred.
class DropOffSiteTest < ActiveSupport::TestCase
  def setup
    @driver = User.create!(
      email:        "driver-#{SecureRandom.hex(4)}@example.com",
      password:     "password",
      phone_number: "+27800000020",
      role:         :driver
    )

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

  def drop(site:, kg:, date:, is_done: true, waste_stream: nil)
    day = DriversDay.find_or_create_by!(date: date, user: @driver)
    DropOffEvent.create!(
      drop_off_site: site,
      drivers_day:   day,
      date:          date,
      weight_kg:     kg,
      is_done:       is_done,
      waste_stream:  waste_stream || site.default_waste_stream
    )
  end

  # ── fees_for ───────────────────────────────────────────────────────────

  test "fees_for returns kg and fee for completed drops in the month" do
    drop(site: @langa, kg: 40.0, date: Date.new(2026, 7, 8))

    assert_equal({ kg: 40.0, fee: 20.0 }, @langa.fees_for(year: 2026, month: 7))
  end

  test "fees_for sums multiple drops in the month" do
    drop(site: @langa, kg: 40.0, date: Date.new(2026, 7, 8))
    drop(site: @langa, kg: 25.5, date: Date.new(2026, 7, 15))

    assert_equal({ kg: 65.5, fee: 32.75 }, @langa.fees_for(year: 2026, month: 7))
  end

  test "fees_for excludes drops that are not done" do
    drop(site: @langa, kg: 40.0, date: Date.new(2026, 7, 8))
    drop(site: @langa, kg: 100.0, date: Date.new(2026, 7, 9), is_done: false)

    assert_equal({ kg: 40.0, fee: 20.0 }, @langa.fees_for(year: 2026, month: 7),
                 "an unfinished drop is not owed for yet")
  end

  test "fees_for respects month boundaries" do
    drop(site: @langa, kg: 10.0, date: Date.new(2026, 6, 30)) # last day of previous month
    drop(site: @langa, kg: 40.0, date: Date.new(2026, 7, 1))  # first day of the month
    drop(site: @langa, kg: 60.0, date: Date.new(2026, 7, 31)) # last day of the month
    drop(site: @langa, kg: 99.0, date: Date.new(2026, 8, 1))  # first day of the next month

    assert_equal({ kg: 100.0, fee: 50.0 }, @langa.fees_for(year: 2026, month: 7))
    assert_equal({ kg: 10.0, fee: 5.0 },   @langa.fees_for(year: 2026, month: 6))
  end

  test "fees_for on a free site is zero even with kilograms dropped" do
    drop(site: @sfl, kg: 200.0, date: Date.new(2026, 7, 8))

    assert_equal({ kg: 200.0, fee: 0.0 }, @sfl.fees_for(year: 2026, month: 7))
  end

  test "fees_for is zero for a month with no drops" do
    assert_equal({ kg: 0.0, fee: 0.0 }, @langa.fees_for(year: 2026, month: 1))
  end

  # ── scopes ─────────────────────────────────────────────────────────────

  test "protein_capable returns only sites that accept protein" do
    assert_includes     DropOffSite.protein_capable, @langa
    assert_not_includes DropOffSite.protein_capable, @sfl
  end

  test "charging excludes free sites" do
    assert_includes     DropOffSite.charging, @langa
    assert_not_includes DropOffSite.charging, @sfl
  end

  test "default_waste_stream follows the site's capability" do
    assert_equal "protein", @langa.default_waste_stream
    assert_equal "general", @sfl.default_waste_stream
  end
end
