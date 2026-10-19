# frozen_string_literal: true
require "test_helper"

class DropOffSiteFeesTest < ActiveSupport::TestCase
  setup do
    driver = User.create!(
      first_name: "Alfred", last_name: "Driver",
      phone_number: "+2782888#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", role: :driver
    )
    @day = DriversDay.create!(user: driver, date: Date.new(2026, 11, 3))
    @site = DropOffSite.create!(
      name: "Fee Farm", street_address: "1 Farm Rd, Observatory",
      suburb: suburb_fixture("Observatory"), collection_day: "Thursday", fee_per_kg: 2
    )
  end

  def drop(date, kg)
    @site.drop_off_events.create!(drivers_day: @day, date: date, weight_kg: kg, is_done: true,
                                  waste_stream: "general")
  end

  test "fees_for counts every drop when there is no start date" do
    drop(Date.new(2026, 11, 3), 10)
    drop(Date.new(2026, 11, 20), 15)

    assert_equal({ kg: 25.0, fee: 50.0 }, @site.fees_for(year: 2026, month: 11))
  end

  test "fees_for ignores drops before the start date, including mid-month" do
    @site.update!(fee_start_date: Date.new(2026, 11, 10))
    drop(Date.new(2026, 11, 3), 10)
    drop(Date.new(2026, 11, 10), 15)

    assert_equal({ kg: 15.0, fee: 30.0 }, @site.fees_for(year: 2026, month: 11))
  end

  test "fees_for is zero for months wholly before the start date" do
    @site.update!(fee_start_date: Date.new(2026, 12, 1))
    drop(Date.new(2026, 11, 3), 10)

    assert_equal({ kg: 0.0, fee: 0.0 }, @site.fees_for(year: 2026, month: 11))
  end

  test "disposal fees report honours the start date" do
    @site.update!(fee_start_date: Date.new(2026, 11, 10))
    drop(Date.new(2026, 11, 3), 10)
    drop(Date.new(2026, 11, 10), 15)

    row = DisposalFeesReport.new(sites: DropOffSite.where(id: @site.id)).rows.first
    assert_equal 15.0, row.kg_dropped
    assert_equal 30.0, row.fee_owed
  end

  test "a site can be saved without compliance details, which are the manager's to supply" do
    assert @site.save
    refute @site.compliance_details_complete?
    assert_equal DropOffSite::COMPLIANCE_FIELDS.values, @site.missing_compliance_fields
    assert @site.action_needed?

    @site.update!(legal_name: "Fee Farm NPC", signatory_name: "Thandi", signatory_title: "Manager",
                  max_kg_per_delivery: 125, max_deliveries_per_week: 2)
    assert @site.compliance_details_complete?
    assert @site.action_needed?, "still has to sign and upload the letter"
    refute @site.facility_paperwork_complete?

    @site.submit_facility_letter(io: StringIO.new("%PDF-1.4"), filename: "l.pdf", content_type: "application/pdf")
    refute @site.action_needed?, "waiting on Gooi's review is not the manager's job"
    refute @site.facility_paperwork_complete?, "an uploaded letter is not enough until Gooi approves it"

    @site.reject_letter!("no signature")
    assert @site.action_needed?

    @site.approve_letter!
    assert @site.facility_paperwork_complete?
    assert @site.compliance_details_locked?
  end

  test "weekly deliveries must be a sensible whole number" do
    @site.max_deliveries_per_week = 0
    refute @site.valid?
    @site.max_deliveries_per_week = 2.5
    refute @site.valid?
    @site.max_deliveries_per_week = 2
    assert @site.valid?
  end

  test "capacity_overages_for flags weight and weekly count, and is silent without limits" do
    event = @site.drop_off_events.create!(drivers_day: @day, date: Date.new(2026, 11, 3), weight_kg: 200, is_done: true, waste_stream: "general")
    assert_empty @site.capacity_overages_for(event)

    @site.update!(max_kg_per_delivery: 125, max_deliveries_per_week: 1)
    assert_equal 1, @site.capacity_overages_for(event).size, "200 kg is over 125 kg; 1 delivery is not over 1"

    second = @site.drop_off_events.create!(drivers_day: @day, date: Date.new(2026, 11, 5), weight_kg: 10, is_done: true, waste_stream: "general")
    assert_match(/2 deliveries this week/, @site.capacity_overages_for(second).join)
  end

  test "letter must be a pdf or image" do
    @site.facility_confirmation_letter.attach(io: StringIO.new("x"), filename: "l.exe", content_type: "application/x-msdownload")

    refute @site.valid?
    assert_includes @site.errors[:facility_confirmation_letter].join, "PDF, JPG or PNG"
  end

  test "missing_facility_letter scope finds sites without one" do
    assert_includes DropOffSite.missing_facility_letter, @site
  end
end
