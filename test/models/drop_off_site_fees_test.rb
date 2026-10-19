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

  test "onboarding requires capacity and a letter, but legacy saves do not" do
    assert @site.save, "plain saves must keep working for legacy sites"

    refute @site.valid?(:onboarding)
    assert_includes @site.errors.attribute_names, :max_kg_per_delivery
    assert_includes @site.errors.attribute_names, :facility_confirmation_letter

    @site.max_kg_per_delivery = 125
    @site.facility_confirmation_letter.attach(io: StringIO.new("%PDF-1.4"), filename: "l.pdf", content_type: "application/pdf")
    assert @site.valid?(:onboarding)
    refute @site.facility_paperwork_complete?, "an attached letter is not enough until Gooi approves it"
    @site.approve_letter!
    assert @site.facility_paperwork_complete?
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
