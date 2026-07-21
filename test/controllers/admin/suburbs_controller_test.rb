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
end
