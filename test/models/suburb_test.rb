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

  test "cannot be destroyed while a subscription references it" do
    suburb = Suburb.create!(name: "Referenced Suburb", collection_day: "Monday")
    user = User.create!(first_name: "Test", last_name: "User", email: "suburb_test@example.com", phone_number: "+27831112222", password: "password")
    Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: suburb.name, suburb_id: suburb.id, street_address: "1 Test Street", collection_day: "Monday")

    assert_not suburb.destroy
    assert_includes suburb.errors[:base], "Cannot delete record because dependent subscriptions exist"
  end
end
