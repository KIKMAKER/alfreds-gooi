# frozen_string_literal: true
require "test_helper"

class DisposalPaymentTest < ActiveSupport::TestCase
  setup do
    driver = User.create!(
      first_name: "Alfred", last_name: "Driver",
      phone_number: "+2782999#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", role: :driver
    )
    @day = DriversDay.create!(user: driver, date: Date.new(2026, 11, 3))
    @site = DropOffSite.create!(
      name: "Paid Farm", street_address: "1 Farm Rd, Observatory",
      suburb: suburb_fixture("Observatory"), collection_day: "Thursday", fee_per_kg: 2
    )
    @site.drop_off_events.create!(drivers_day: @day, date: Date.new(2026, 11, 3), weight_kg: 50, is_done: true, waste_stream: "general")
  end

  test "request_for! snapshots kg, rate and amount" do
    payment = DisposalPayment.request_for!(@site, month: Date.new(2026, 11, 17))

    assert_equal Date.new(2026, 11, 1), payment.period
    assert_equal 50, payment.kg
    assert_equal 2, payment.fee_per_kg
    assert_equal 100, payment.amount
    assert payment.requested?
  end

  test "request_for! is idempotent per month and refreshes an unpaid request" do
    first = DisposalPayment.request_for!(@site, month: Date.new(2026, 11, 1))
    @site.drop_off_events.create!(drivers_day: @day, date: Date.new(2026, 11, 10), weight_kg: 25, is_done: true, waste_stream: "general")
    second = DisposalPayment.request_for!(@site, month: Date.new(2026, 11, 1))

    assert_equal first.id, second.id
    assert_equal 150, second.amount
    assert_equal 1, DisposalPayment.count
  end

  test "request_for! never asks a free site for anything" do
    @site.update!(fee_per_kg: 0)

    assert_nil DisposalPayment.request_for!(@site, month: Date.new(2026, 11, 1))
    assert_equal 0, DisposalPayment.count
  end

  test "request_for! returns nil when nothing is billable" do
    assert_nil DisposalPayment.request_for!(@site, month: Date.new(2026, 10, 1))
  end

  test "mark_paid! is refused until the site is a listed facility" do
    payment = DisposalPayment.request_for!(@site, month: Date.new(2026, 11, 1))

    assert_raises(DisposalPayment::NotPayable) { payment.mark_paid! }
    refute payment.reload.paid?

    @site.facility_confirmation_letter.attach(io: StringIO.new("%PDF"), filename: "l.pdf", content_type: "application/pdf")
    @site.approve_letter!
    payment.mark_paid!

    assert payment.reload.paid?
    assert_not_nil payment.paid_at
  end

  test "a paid month is not overwritten by a later request" do
    @site.approve_letter!
    payment = DisposalPayment.request_for!(@site, month: Date.new(2026, 11, 1))
    payment.mark_paid!
    @site.drop_off_events.create!(drivers_day: @day, date: Date.new(2026, 11, 10), weight_kg: 25, is_done: true, waste_stream: "general")

    assert_equal 100, DisposalPayment.request_for!(@site, month: Date.new(2026, 11, 1)).amount
  end

  test "letter workflow: submit, reject, resubmit, approve" do
    pdf = ->(name) { { io: StringIO.new("%PDF-1.4"), filename: name, content_type: "application/pdf" } }

    assert @site.letter_not_submitted?
    assert @site.submit_facility_letter(pdf.("a.pdf"))
    assert @site.letter_submitted?
    refute @site.payable?

    @site.reject_letter!("Please sign it")
    assert @site.letter_rejected?
    assert_equal "Please sign it", @site.facility_rejection_reason

    assert @site.submit_facility_letter(pdf.("b.pdf"))
    assert @site.letter_submitted?
    assert_nil @site.facility_rejection_reason

    @site.approve_letter!
    assert @site.payable?
  end

  test "a bad file leaves the site's review state untouched" do
    refute @site.submit_facility_letter(io: StringIO.new("MZ\x90\x00\x03 not a pdf"), filename: "x.exe", content_type: "application/x-msdownload")
    assert @site.reload.letter_not_submitted?
  end
end
