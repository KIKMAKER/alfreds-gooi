# frozen_string_literal: true
require "test_helper"

class DisposalPaymentMailerTest < ActionMailer::TestCase
  setup do
    manager = User.create!(
      first_name: "Thandi", last_name: "Manager",
      phone_number: "+2782123#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", role: :drop_off
    )
    driver = User.create!(
      first_name: "Alfred", last_name: "Driver",
      phone_number: "+2782124#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", role: :driver
    )
    @site = DropOffSite.create!(
      name: "Mail Farm", street_address: "1 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", fee_per_kg: 2, user: manager
    )
    day = DriversDay.create!(user: driver, date: Date.new(2026, 11, 3))
    @site.drop_off_events.create!(drivers_day: day, date: Date.new(2026, 11, 3), weight_kg: 50, is_done: true, waste_stream: "general")
    @payment = DisposalPayment.request_for!(@site, month: Date.new(2026, 11, 1))
  end

  test "states the calculated amount and asks for banking details" do
    mail = DisposalPaymentMailer.payment_request(@payment)

    assert_equal [@site.user.email], mail.to
    assert_match "R100.00", mail.subject
    assert_match "50.0 kg", mail.body.encoded
    assert_match "Banking details", mail.body.encoded
  end

  test "an unlisted site is told it can't be paid until it is listed" do
    body = DisposalPaymentMailer.payment_request(@payment).body.encoded

    assert_match "can't pay you unless you're listed as a facility", body
    assert_match "Upload signed letter", body
  end

  test "a site awaiting review is told it is being reviewed, without the warning" do
    @site.submit_facility_letter(io: StringIO.new("%PDF"), filename: "l.pdf", content_type: "application/pdf")
    body = DisposalPaymentMailer.payment_request(@payment).body.encoded

    assert_match "reviewing it", body
    assert_no_match(/unless you/, body)
  end

  test "a listed site gets no gate at all" do
    @site.approve_letter!
    body = DisposalPaymentMailer.payment_request(@payment).body.encoded

    assert_no_match(/unless you/, body)
    assert_no_match(/Upload signed letter/, body)
  end
end

class FacilityLetterMailerTest < ActionMailer::TestCase
  setup do
    manager = User.create!(
      first_name: "Thandi", last_name: "Manager",
      phone_number: "+2782125#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", role: :drop_off
    )
    @free_site = DropOffSite.create!(
      name: "Free Farm", street_address: "1 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", fee_per_kg: 0, user: manager
    )
    @paid_site = DropOffSite.create!(
      name: "Paid Farm", street_address: "2 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", fee_per_kg: 1.5, user: manager
    )
  end

  test "submitted goes to Gooi with the letter attached" do
    @free_site.submit_facility_letter(io: StringIO.new("%PDF"), filename: "signed.pdf", content_type: "application/pdf")
    mail = FacilityLetterMailer.submitted(@free_site)

    assert_equal ["howzit@gooi.me"], mail.to
    assert_equal 1, mail.attachments.size
    assert_equal "signed.pdf", mail.attachments.first.filename
  end

  test "approval email never mentions payment for a free site" do
    body = FacilityLetterMailer.approved(@free_site).body.encoded

    assert_match "listed facility", body
    assert_no_match(/pay|fee|R\d/i, body)
  end

  test "approval email tells a charging site it is clear to be paid" do
    assert_match "clear to pay you", FacilityLetterMailer.approved(@paid_site).body.encoded
  end
end
