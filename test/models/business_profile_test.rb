require "test_helper"

class BusinessProfileTest < ActiveSupport::TestCase
  test "suburb is optional" do
    user = User.create!(first_name: "Test", last_name: "User", email: "bp_test@example.com", phone_number: "+27831112223", password: "password")
    subscription = Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: "Woodstock", street_address: "1 Test Street", collection_day: "Monday")

    profile = BusinessProfile.new(subscription: subscription, business_name: "Test Co")
    assert profile.valid?
  end

  test "can reference an active suburb" do
    suburb = Suburb.create!(name: "Woodstock", collection_day: "Monday")
    user = User.create!(first_name: "Test", last_name: "User", email: "bp_test2@example.com", phone_number: "+27831112224", password: "password")
    subscription = Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: "Woodstock", street_address: "1 Test Street", collection_day: "Monday")

    profile = BusinessProfile.create!(subscription: subscription, business_name: "Test Co", suburb: suburb)
    assert_equal suburb, profile.suburb
  end
end
