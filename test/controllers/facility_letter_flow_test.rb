# frozen_string_literal: true
require "test_helper"

class FacilityLetterFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @manager = User.create!(
      first_name: "Thandi", last_name: "Manager",
      phone_number: "+2782321#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", role: :drop_off
    )
    @admin = User.create!(
      first_name: "Kiki", last_name: "Admin",
      phone_number: "+2782322#{rand(1000..9999)}", password: "password",
      email: "admin-#{SecureRandom.hex(3)}@gmail.com", role: :admin
    )
    @driver = User.create!(
      first_name: "Alfred", last_name: "Driver",
      phone_number: "+2782323#{rand(1000..9999)}", password: "password",
      email: "driver-#{SecureRandom.hex(3)}@gmail.com", role: :driver
    )
    @site = DropOffSite.create!(
      name: "Letter Farm", street_address: "1 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", fee_per_kg: 0, user: @manager
    )
  end

  # Active Storage sniffs the real type from the bytes, so a "bad" file needs bad bytes.
  def complete_details(site = @site)
    site.update!(legal_name: "Letter Farm NPC", signatory_name: "Thandi Manager", signatory_title: "Farm Manager",
                 max_kg_per_delivery: 125, max_deliveries_per_week: 2)
  end

  def pdf_upload(name = "signed.pdf", type = "application/pdf", bytes = "%PDF-1.4")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: name)
  end

  # ── Manager side ──

  test "free site: home and compliance pages never mention payment or fees" do
    sign_in @manager

    [drop_off_site_manager_path(@site), compliance_drop_off_site_manager_path(@site)].each do |path|
      get path
      assert_response :success
      text = css_select(".subscription-show-container").map(&:text).join(" ")
      assert_no_match(/can't pay|disposal fee|per kg|\/ kg|\bfees?\b|payment/i, text, "#{path} mentioned cost to a free site")
    end
  end

  test "charging site: home and compliance warn it can't be paid until listed" do
    @site.update!(fee_per_kg: 2)
    sign_in @manager

    [drop_off_site_manager_path(@site), compliance_drop_off_site_manager_path(@site)].each do |path|
      get path
      assert_match "We can't pay you unless you're listed as a facility", response.body
    end
  end

  test "manager downloads a letter already filled in with their details" do
    complete_details
    sign_in @manager
    get letter_template_drop_off_site_manager_path(@site)

    assert_response :success
    assert_match "wordprocessingml", response.media_type
    xml = Zip::File.open_buffer(StringIO.new(response.body)).read("word/document.xml")
    assert_match "Letter Farm NPC", xml
    assert_match "twice a week", xml
    assert_no_match(/\{\{/, xml)
  end

  test "the letter download is refused until the details are filled in" do
    sign_in @manager
    get letter_template_drop_off_site_manager_path(@site)

    assert_redirected_to compliance_drop_off_site_manager_path(@site)
  end

  test "uploading a letter is refused until the details are filled in" do
    sign_in @manager

    assert_no_emails do
      post submit_letter_drop_off_site_manager_path(@site), params: { facility_letter: pdf_upload }
    end

    assert @site.reload.letter_not_submitted?
  end

  test "uploading a letter marks it submitted and emails Gooi" do
    complete_details
    sign_in @manager

    assert_emails 1 do
      post submit_letter_drop_off_site_manager_path(@site), params: { facility_letter: pdf_upload }
    end

    assert_redirected_to compliance_drop_off_site_manager_path(@site)
    assert @site.reload.letter_submitted?
    assert @site.facility_confirmation_letter.attached?
  end

  test "a wrong file type is refused and nothing is emailed" do
    complete_details
    sign_in @manager

    assert_no_emails do
      post submit_letter_drop_off_site_manager_path(@site), params: { facility_letter: pdf_upload("x.exe", "application/x-msdownload", "MZ\x90\x00\x03 not a pdf") }
    end

    assert @site.reload.letter_not_submitted?
    follow_redirect!
    assert_match "PDF, JPG or PNG", response.body
  end

  test "submitting with no file is refused" do
    complete_details
    sign_in @manager
    post submit_letter_drop_off_site_manager_path(@site)

    assert @site.reload.letter_not_submitted?
  end

  test "a manager cannot upload a letter for someone else's site" do
    other = DropOffSite.create!(
      name: "Other Farm", street_address: "9 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", fee_per_kg: 0
    )
    sign_in @manager
    post submit_letter_drop_off_site_manager_path(other), params: { facility_letter: pdf_upload }

    assert other.reload.letter_not_submitted?
  end

  # ── Admin side ──

  test "admin approves a submitted letter and the manager is emailed" do
    @site.submit_facility_letter(io: StringIO.new("%PDF"), filename: "l.pdf", content_type: "application/pdf")
    sign_in @admin

    assert_emails 1 do
      post approve_letter_admin_drop_off_site_path(@site.slug)
    end

    assert @site.reload.letter_approved?
    assert @site.payable?
  end

  test "admin rejects with a reason and the manager is emailed it" do
    @site.submit_facility_letter(io: StringIO.new("%PDF"), filename: "l.pdf", content_type: "application/pdf")
    sign_in @admin

    assert_emails 1 do
      post reject_letter_admin_drop_off_site_path(@site.slug), params: { reason: "Missing signature" }
    end

    assert @site.reload.letter_rejected?
    assert_equal "Missing signature", @site.facility_rejection_reason
  end

  test "approving with no letter attached does nothing" do
    sign_in @admin
    post approve_letter_admin_drop_off_site_path(@site.slug)

    assert @site.reload.letter_not_submitted?
  end

  test "admin review panel only shows once a letter is waiting" do
    sign_in @admin
    get admin_drop_off_site_path(@site.slug)
    assert_no_match(/Review facility letter/, response.body)

    @site.submit_facility_letter(io: StringIO.new("%PDF"), filename: "l.pdf", content_type: "application/pdf")
    get admin_drop_off_site_path(@site.slug)
    assert_match "Review facility letter", response.body
  end

  test "dashboard counts letters awaiting review" do
    @site.submit_facility_letter(io: StringIO.new("%PDF"), filename: "l.pdf", content_type: "application/pdf")
    sign_in @admin
    get admin_root_path

    assert_match "1 facility letter to review", response.body
  end

  # ── Payment requests ──

  def charging_site_with_drops
    site = DropOffSite.create!(
      name: "Fee Farm", street_address: "5 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", fee_per_kg: 2, user: @manager
    )
    day = DriversDay.create!(user: @driver, date: Date.new(2026, 8, 5))
    site.drop_off_events.create!(drivers_day: day, date: Date.new(2026, 8, 5), weight_kg: 50, is_done: true, waste_stream: "general")
    site
  end

  test "admin sends a payment request email with the calculated amount" do
    site = charging_site_with_drops
    sign_in @admin

    assert_emails 1 do
      post admin_disposal_payments_path, params: { site: site.slug, month: "2026-08" }
    end

    assert_equal 100, DisposalPayment.find_by!(drop_off_site: site).amount
    assert_match "R100.00", ActionMailer::Base.deliveries.last.subject
  end

  test "no payment request is ever sent for a free site" do
    sign_in @admin

    assert_no_emails do
      post admin_disposal_payments_path, params: { site: @site.slug, month: "2026-08" }
    end

    assert_equal 0, DisposalPayment.count
  end

  test "admin cannot mark an unlisted site paid" do
    site = charging_site_with_drops
    payment = DisposalPayment.request_for!(site, month: Date.new(2026, 8, 1))
    sign_in @admin

    post mark_paid_admin_disposal_payment_path(payment)

    assert_redirected_to admin_disposal_fees_path
    refute payment.reload.paid?
  end

  test "admin can mark a listed site paid" do
    site = charging_site_with_drops
    site.approve_letter!
    payment = DisposalPayment.request_for!(site, month: Date.new(2026, 8, 1))
    sign_in @admin

    post mark_paid_admin_disposal_payment_path(payment)

    assert payment.reload.paid?
  end

  test "fees page shows the can't-pay warning for an unlisted site" do
    charging_site_with_drops
    sign_in @admin
    get admin_disposal_fees_path

    assert_response :success
    assert_match "can't pay", response.body
  end
end
