require "test_helper"

class Admin::SuburbsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Kiki", last_name: "Kennedy",
      phone_number: "+2783635#{rand(1000..9999)}", password: "password",
      email: "admin-#{SecureRandom.hex(3)}@gmail.com", role: :admin
    )
    sign_in @admin
  end

  test "start_launch redirects with an alert when the suburb has no launch_date" do
    suburb = Suburb.create!(name: "New Area", status: :target)

    post start_launch_admin_suburb_path(suburb)

    assert_redirected_to admin_suburbs_path
    assert_equal "Set a launch date before starting pre-launch.", flash[:alert]
    assert suburb.reload.target?
  end

  test "start_launch moves a suburb with a launch_date onto the waitlist" do
    suburb = Suburb.create!(name: "New Area", status: :target, launch_date: Date.tomorrow)

    post start_launch_admin_suburb_path(suburb)

    assert_redirected_to admin_suburbs_path
    assert_equal "New Area is now on the pre-launch waitlist.", flash[:notice]
    assert suburb.reload.waitlist?
  end

  test "go_live redirects with an alert when the suburb isn't on the waitlist" do
    suburb = Suburb.create!(name: "New Area", status: :target)

    post go_live_admin_suburb_path(suburb)

    assert_redirected_to admin_suburbs_path
    assert_equal "New Area isn't on the pre-launch waitlist.", flash[:alert]
    assert suburb.reload.target?
  end

  test "go_live moves a waitlisted suburb to active" do
    suburb = Suburb.create!(name: "New Area", status: :waitlist, launch_date: Date.tomorrow, collection_day: "Monday")

    post go_live_admin_suburb_path(suburb)

    assert_redirected_to admin_suburbs_path
    assert_equal "New Area is live!", flash[:notice]
    assert suburb.reload.active?
  end

  test "show renders interest signups for a target suburb" do
    suburb = Suburb.create!(name: "New Area", status: :target)
    Interest.create!(name: "Prospective Customer", email: "prospect@example.com", suburb: suburb)

    get admin_suburb_path(suburb)

    assert_response :success
    assert_select "td", text: "Prospective Customer"
  end

  test "show splits paid vs unpaid signups for a waitlist suburb" do
    suburb = Suburb.create!(name: "New Area", status: :waitlist, launch_date: Date.tomorrow, collection_day: "Monday")

    paid_user = User.create!(first_name: "Paid", last_name: "Customer", email: "paid@example.com", phone_number: "+27831110001", password: "password")
    paid_sub = Subscription.create!(user: paid_user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Test St", status: :pending)
    Invoice.create!(subscription: paid_sub, paid: true, total_amount: 220, issued_date: Date.current, due_date: Date.current + 14)

    unpaid_user = User.create!(first_name: "Unpaid", last_name: "Customer", email: "unpaid@example.com", phone_number: "+27831110002", password: "password")
    Subscription.create!(user: unpaid_user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Test St", status: :pending)

    get admin_suburb_path(suburb)

    assert_response :success
    assert_select "td", text: "Paid Customer"
    assert_select "td", text: "Unpaid Customer"
    assert_select "span.badge", text: "Paid"
    assert_select "span.badge", text: "Awaiting payment"
  end

  test "show renders subscriptions for an active suburb" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    user = User.create!(first_name: "Active", last_name: "Customer", email: "active@example.com", phone_number: "+27831110003", password: "password")
    Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Test St", status: :active)

    get admin_suburb_path(suburb)

    assert_response :success
    assert_select "td", text: "Active Customer"
  end

  test "show renders drop-off sites for a drop_off_only suburb" do
    suburb = Suburb.create!(name: "Drop Off Area", status: :drop_off_only)
    DropOffSite.create!(name: "Test Farm", street_address: "1 Test St", suburb: suburb, collection_day: "Monday", fee_per_kg: 0)

    get admin_suburb_path(suburb)

    assert_response :success
    assert_select "td", text: "Test Farm"
  end
end
