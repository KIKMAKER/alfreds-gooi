# frozen_string_literal: true
require "test_helper"

class DropOffSiteManagersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @manager = User.create!(
      first_name: "Thandi", last_name: "Manager",
      phone_number: "+2782333#{rand(1000..9999)}", password: "password",
      email: "thandi-#{SecureRandom.hex(3)}@gmail.com", role: :drop_off
    )
    @driver = User.create!(
      first_name: "Alfred", last_name: "Driver",
      phone_number: "+2782444#{rand(1000..9999)}", password: "password",
      email: "alfred-#{SecureRandom.hex(3)}@gmail.com", role: :driver
    )
    @drivers_day = DriversDay.create!(user: @driver, date: Date.current)

    @site = DropOffSite.create!(
      name: "Neighbourhood Farm", street_address: "1 Farm Rd, Observatory",
      suburb: suburb_fixture("Observatory"), collection_day: "Thursday",
      fee_per_kg: 2.5, user: @manager
    )
    @other_site = DropOffSite.create!(
      name: "Someone Else's Farm", street_address: "9 Other Rd, Observatory",
      suburb: suburb_fixture("Observatory"), collection_day: "Thursday",
      fee_per_kg: 0, user: User.create!(
        first_name: "Other", last_name: "Manager",
        phone_number: "+2782555#{rand(1000..9999)}", password: "password",
        email: "other-#{SecureRandom.hex(3)}@gmail.com", role: :drop_off
      )
    )

    @done = @drivers_day.drop_off_events.create!(
      drop_off_site: @site, date: Date.current, is_done: true, weight_kg: 40,
      waste_stream: @site.default_waste_stream
    )
    @other_site.drop_off_events.create!(
      drivers_day: @drivers_day, date: Date.current, is_done: true, weight_kg: 999,
      waste_stream: @other_site.default_waste_stream
    )

    sign_in @manager
  end

  test "customers are turned away" do
    sign_out @manager
    customer = User.create!(
      first_name: "Nina", last_name: "Customer",
      phone_number: "+2782666#{rand(1000..9999)}", password: "password",
      email: "nina-#{SecureRandom.hex(3)}@gmail.com"
    )
    sign_in customer

    get drop_off_impact_path
    assert_redirected_to root_path
  end

  test "home shows the site, stats and the disposal fee card for a charging site" do
    get drop_off_site_manager_path(@site)

    assert_response :success
    assert_match(/Neighbourhood Farm/, response.body)
    assert_match(/Next drop-off/, response.body)
    assert_match(/Disposal fee/, response.body)
    assert_match(/R2\.50/, response.body)
  end

  test "home omits the disposal fee card for a free site" do
    @site.update!(fee_per_kg: 0)

    get drop_off_site_manager_path(@site)

    assert_response :success
    assert_no_match(/Disposal fee/, response.body)
  end

  test "manager cannot open another manager's site" do
    get drop_off_site_manager_path(@other_site)

    assert_redirected_to drop_off_site_managers_path
  end

  test "impact only counts this manager's completed drop-offs" do
    get drop_off_impact_path

    assert_response :success
    assert_match(/40kg/, response.body)
    assert_no_match(/999kg/, response.body)
  end

  test "history lists completed drop-offs and scopes to the manager" do
    get drop_off_history_path

    assert_response :success
    assert_match(/All Drop-offs/, response.body)
    assert_match(/1 total/, response.body)
  end

  test "history tolerates a junk page param" do
    get drop_off_history_path(page: "-4", per: "abc")

    assert_response :success
  end

  test "account page renders for a manager without a subscription" do
    get account_path

    assert_response :success
  end

  test "bottom nav is the drop-off one, not the customer one" do
    get drop_off_site_manager_path(@site)

    assert_select "nav#customer-bottom-nav a[href=?]", drop_off_impact_path
    assert_select "nav#customer-bottom-nav a[href=?]", my_stats_path, count: 0
  end

  test "updating account details lands a manager back on their site, not the root" do
    put user_registration_path, params: { user: { first_name: "Thandi", current_password: "password" } }

    assert_redirected_to drop_off_site_manager_path(@site)
  end

  test "updating account details lands a customer on manage" do
    sign_out @manager
    customer = User.create!(
      first_name: "Nina", last_name: "Customer",
      phone_number: "+2782777#{rand(1000..9999)}", password: "password",
      email: "nina-#{SecureRandom.hex(3)}@gmail.com"
    )
    sign_in customer

    put user_registration_path, params: { user: { first_name: "Nina", current_password: "password" } }

    assert_redirected_to manage_path
  end

  test "compliance page shows the approved letter and locked figures" do
    @site.update!(legal_name: "Farm NPC", signatory_name: "Thandi", signatory_title: "Manager",
                  max_kg_per_delivery: 125, max_deliveries_per_week: 2)
    @site.facility_confirmation_letter.attach(io: StringIO.new("%PDF-1.4"), filename: "letter.pdf", content_type: "application/pdf")
    @site.approve_letter!

    get compliance_drop_off_site_manager_path(@site)

    assert_match(/You&#39;re a listed facility|You're a listed facility/, response.body)
    assert_match(/Farm NPC/, response.body)
    assert_match(/View your signed letter/, response.body)
  end

  test "home says fees start later when the start date is in the future" do
    @site.update!(fee_start_date: Date.current + 30)

    get drop_off_site_manager_path(@site)

    assert_match(/Fees start/, response.body)
  end
end
