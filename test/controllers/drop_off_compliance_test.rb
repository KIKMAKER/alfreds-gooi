# frozen_string_literal: true
require "test_helper"

class DropOffComplianceTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @manager = User.create!(
      first_name: "Thandi", last_name: "Manager",
      phone_number: "+2782411#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", role: :drop_off
    )
    @site = DropOffSite.create!(
      name: "Comply Farm", street_address: "1 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", fee_per_kg: 0, user: @manager, contact_name: "Thandi"
    )
    sign_in @manager
  end

  def details
    { legal_name: "Comply Farm NPC", signatory_name: "Thandi M", signatory_title: "Manager",
      max_kg_per_delivery: 125, max_deliveries_per_week: 2 }
  end

  test "an empty site makes the missing fields obvious everywhere" do
    get drop_off_site_manager_path(@site)
    assert_match "Action needed", response.body
    assert_match "Complete compliance", response.body

    get compliance_drop_off_site_manager_path(@site)
    assert_response :success
    assert_equal 5, css_select(".dom-field--todo").size, "every blank field should be highlighted"
    assert_equal 5, css_select(".dom-field__hint").count { |n| n.text.include?("Still needed") }
    assert_match "After step 1", response.body
    assert_no_match(/Download your letter/, response.body)
  end

  test "bottom nav carries an action-needed dot until the manager is done" do
    get drop_off_site_manager_path(@site)
    assert_select "nav#customer-bottom-nav a.dom-nav-flagged[href=?]", compliance_drop_off_site_manager_path(@site)

    @site.update!(details)
    @site.submit_facility_letter(io: StringIO.new("%PDF"), filename: "l.pdf", content_type: "application/pdf")
    get drop_off_site_manager_path(@site)
    assert_select "nav#customer-bottom-nav a.dom-nav-flagged", count: 0
  end

  test "saving details fills the form in and unlocks the download" do
    patch update_compliance_drop_off_site_manager_path(@site), params: { drop_off_site: details }
    assert_redirected_to compliance_drop_off_site_manager_path(@site)

    @site.reload
    assert @site.compliance_details_complete?
    assert_equal 125, @site.max_kg_per_delivery
    assert_equal 2, @site.max_deliveries_per_week

    get compliance_drop_off_site_manager_path(@site)
    assert_equal 0, css_select(".dom-field--todo").size
    assert_match "Download your letter", response.body
  end

  test "bad figures are rejected with the form re-shown" do
    patch update_compliance_drop_off_site_manager_path(@site), params: { drop_off_site: details.merge(max_deliveries_per_week: 99) }

    assert_response :unprocessable_entity
    assert_nil @site.reload.max_deliveries_per_week
  end

  test "once the letter is approved the details are locked" do
    @site.update!(details)
    @site.approve_letter!

    patch update_compliance_drop_off_site_manager_path(@site), params: { drop_off_site: { max_kg_per_delivery: 5000 } }

    assert_redirected_to compliance_drop_off_site_manager_path(@site)
    assert_equal 125, @site.reload.max_kg_per_delivery
  end

  test "a manager cannot change another site's details" do
    other = DropOffSite.create!(
      name: "Not Mine", street_address: "9 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", fee_per_kg: 0
    )
    patch update_compliance_drop_off_site_manager_path(other), params: { drop_off_site: details }

    assert_nil other.reload.legal_name
  end

  test "manager can't smuggle in fields they shouldn't set" do
    patch update_compliance_drop_off_site_manager_path(@site),
          params: { drop_off_site: details.merge(fee_per_kg: 99, facility_letter_status: "approved") }

    @site.reload
    assert_equal 0, @site.fee_per_kg
    assert @site.letter_not_submitted?
  end

  test "multi-site managers see a flag per site on the picker" do
    DropOffSite.create!(
      name: "Second Farm", street_address: "2 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Tuesday", fee_per_kg: 0, user: @manager
    )
    get drop_off_site_managers_path

    assert_equal 2, css_select(".dom-alert--compact").size
  end

  test "the whole journey: details, download, upload, approve" do
    patch update_compliance_drop_off_site_manager_path(@site), params: { drop_off_site: details }
    get letter_template_drop_off_site_manager_path(@site)
    assert_response :success

    post submit_letter_drop_off_site_manager_path(@site),
         params: { facility_letter: Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4"), "application/pdf", original_filename: "s.pdf") }
    assert @site.reload.letter_submitted?

    get compliance_drop_off_site_manager_path(@site)
    assert_match "With Gooi for review", response.body

    @site.approve_letter!
    get compliance_drop_off_site_manager_path(@site)
    assert_match "listed facility", response.body
  end
end

class DropOffCapacityWarningTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    driver = User.create!(
      first_name: "Alfred", last_name: "Driver",
      phone_number: "+2782412#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", role: :driver
    )
    @day = DriversDay.create!(user: driver, date: Date.new(2026, 11, 3))
    @site = DropOffSite.create!(
      name: "Cap Farm", street_address: "1 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Tuesday", max_kg_per_delivery: 100, max_deliveries_per_week: 2
    )
  end

  def drop(date, kg)
    @site.drop_off_events.create!(drivers_day: @day, date: date, weight_kg: kg, waste_stream: "general")
  end

  test "completing a drop over the weight limit emails Gooi, not the site" do
    event = drop(Date.new(2026, 11, 3), 150)

    assert_emails 1 do
      event.update!(is_done: true)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal ["howzit@gooi.me"], mail.to
    assert_match "Over capacity at Cap Farm", mail.subject
    assert_match "150.0 kg delivered", mail.body.encoded
  end

  test "a drop within both limits sends nothing" do
    event = drop(Date.new(2026, 11, 3), 80)

    assert_no_emails { event.update!(is_done: true) }
  end

  test "a third delivery in one week trips the weekly limit" do
    drop(Date.new(2026, 11, 2), 10).update!(is_done: true)
    drop(Date.new(2026, 11, 4), 10).update!(is_done: true)
    third = drop(Date.new(2026, 11, 6), 10)

    assert_emails 1 do
      third.update!(is_done: true)
    end
    assert_match "3 deliveries this week", ActionMailer::Base.deliveries.last.body.encoded
  end

  test "deliveries in different weeks are not added together" do
    drop(Date.new(2026, 10, 27), 10).update!(is_done: true)
    drop(Date.new(2026, 10, 29), 10).update!(is_done: true)

    assert_no_emails { drop(Date.new(2026, 11, 3), 10).update!(is_done: true) }
  end

  test "sites with no limits set are never warned about" do
    @site.update!(max_kg_per_delivery: nil, max_deliveries_per_week: nil)

    assert_no_emails { drop(Date.new(2026, 11, 3), 9999).update!(is_done: true) }
  end

  test "editing an already-done event does not warn again" do
    event = drop(Date.new(2026, 11, 3), 150)
    event.update!(is_done: true)

    assert_no_emails { event.update!(driver_note: "heavy one") }
  end

  test "a failing warning email never blocks completing the drop-off" do
    event = drop(Date.new(2026, 11, 3), 150)

    CapacityMailer.stub(:exceeded, ->(*) { raise "postmark is down" }) do
      assert event.update(is_done: true)
    end
    assert event.reload.is_done
  end
end
