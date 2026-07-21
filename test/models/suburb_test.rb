require "test_helper"

class SuburbTest < ActiveSupport::TestCase
  test "generates a slug from the name" do
    suburb = Suburb.create!(name: "Sea Point", collection_day: "Wednesday")
    assert_equal "sea-point", suburb.slug
  end

  test "generates a collision-safe slug" do
    Suburb.create!(name: "Sea Point", collection_day: "Wednesday")
    suburb = Suburb.create!(name: "Sea Point!!", collection_day: "Wednesday")
    assert_equal "sea-point-1", suburb.slug
  end

  test "defaults to active status" do
    suburb = Suburb.create!(name: "Woodstock", collection_day: "Monday")
    assert suburb.active?
  end

  test "enforces unique name" do
    Suburb.create!(name: "Rondebosch", collection_day: "Tuesday")
    duplicate = Suburb.new(name: "Rondebosch", collection_day: "Tuesday")
    assert_not duplicate.valid?
  end

  test "requires a collection_day when active" do
    suburb = Suburb.new(name: "Newlands", status: :active)
    assert_not suburb.valid?
    assert_includes suburb.errors[:collection_day], "can't be blank"
  end

  test "does not require a collection_day when waitlist or target" do
    suburb = Suburb.new(name: "Somewhere Else", status: :target)
    assert suburb.valid?
  end

  test "requires a launch_date when status is waitlist" do
    suburb = Suburb.new(name: "Bo-Kaap Extension", status: :waitlist)
    assert_not suburb.valid?
    assert_includes suburb.errors[:launch_date], "can't be blank"
  end

  test "waitlist? is false without a launch_date even if status is waitlist" do
    suburb = Suburb.new(name: "Bo-Kaap Extension", status: :waitlist, launch_date: nil)
    assert_not suburb.waitlist?
  end

  test "waitlist? is true when status is waitlist and launch_date is present" do
    suburb = Suburb.new(name: "Bo-Kaap Extension", status: :waitlist, launch_date: Date.tomorrow)
    assert suburb.waitlist?
  end

  test "waitlist? is false once status is active, regardless of launch_date" do
    suburb = Suburb.create!(name: "Bo-Kaap Extension", status: :active, collection_day: "Monday", launch_date: Date.yesterday)
    assert_not suburb.waitlist?
  end

  test "start_launch! fails without a launch_date" do
    suburb = Suburb.create!(name: "New Area", status: :target)
    assert_not suburb.start_launch!
    assert suburb.target?
  end

  test "start_launch! fails when already active" do
    suburb = Suburb.create!(name: "Existing Area", status: :active, collection_day: "Monday", launch_date: Date.tomorrow)
    assert_not suburb.start_launch!
    assert suburb.active?
  end

  test "start_launch! moves a suburb with a launch_date onto the waitlist" do
    suburb = Suburb.create!(name: "New Area", status: :target, launch_date: Date.tomorrow)
    assert suburb.start_launch!
    assert suburb.waitlist?
  end

  test "go_live! fails when not on the waitlist" do
    suburb = Suburb.create!(name: "New Area", status: :target)
    assert_not suburb.go_live!
    assert suburb.target?
  end

  test "go_live! moves a waitlisted suburb to active and keeps launch_date" do
    suburb = Suburb.create!(name: "New Area", status: :waitlist, launch_date: Date.tomorrow, collection_day: "Monday")
    assert suburb.go_live!
    assert suburb.active?
    assert_equal Date.tomorrow, suburb.launch_date
  end

  test "go_live! fails cleanly (does not raise) when waitlisted but missing a collection_day" do
    suburb = Suburb.create!(name: "New Area", status: :waitlist, launch_date: Date.tomorrow)
    assert_not suburb.go_live!
    assert suburb.reload.waitlist?
  end

  test "cannot be destroyed while a subscription references it" do
    suburb = Suburb.create!(name: "Referenced Suburb", collection_day: "Monday")
    user = User.create!(first_name: "Test", last_name: "User", email: "suburb_test@example.com", phone_number: "+27831112222", password: "password")
    Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Test Street", collection_day: "Monday")

    assert_not suburb.destroy
    assert_includes suburb.errors[:base], "Cannot delete record because dependent subscriptions exist"
  end
end
