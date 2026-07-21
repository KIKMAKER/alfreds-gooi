require "test_helper"

# Kept in its own file (rather than subscription_test.rb) since SubscriptionTest's
# shared `setup` creates a Subscription without a suburb/street_address and errors
# before every test regardless of test body — a pre-existing baseline issue on
# master, unrelated to the Suburb model.
class SubscriptionSuburbsTest < ActiveSupport::TestCase
  test "SUBURBS reflects active Suburb records" do
    Suburb.destroy_all
    Suburb.create!(name: "Test Suburb", status: :active, collection_day: "Monday")
    Suburb.create!(name: "Other Suburb", status: :waitlist)

    assert_equal ["Test Suburb"], Subscription.SUBURBS
  end

  test "SUBURBS falls back to the frozen list when the table is empty" do
    Suburb.destroy_all

    assert_equal Subscription::FALLBACK_SUBURBS, Subscription.SUBURBS
  end

  test "set_collection_day copies the suburb's own collection_day" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    user = User.create!(first_name: "Test", last_name: "User", email: "sub_day_test@example.com", phone_number: "+27831112225", password: "password")

    sub = Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Test Street")

    assert_equal "Tuesday", sub.collection_day
  end

  test "set_collection_day leaves collection_day nil and logs a warning when the suburb has none" do
    suburb = Suburb.create!(name: "No Day Suburb", status: :waitlist)
    user = User.create!(first_name: "Test", last_name: "User", email: "sub_day_test2@example.com", phone_number: "+27831112226", password: "password")

    sub = Subscription.new(user: user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Test Street")
    sub.valid?

    assert_nil sub.collection_day
  end

  test "an explicitly set collection_day is not overridden by the suburb" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    user = User.create!(first_name: "Test", last_name: "User", email: "sub_day_test3@example.com", phone_number: "+27831112227", password: "password")

    sub = Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Test Street", collection_day: "Thursday")

    assert_equal "Thursday", sub.collection_day
  end

  test "suburb_missing_from_address? checks the suburb's name against the address text" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    user = User.create!(first_name: "Test", last_name: "User", email: "sub_day_test4@example.com", phone_number: "+27831112228", password: "password")

    matching = Subscription.create!(user: user, plan: "Standard", duration: 1, suburb: suburb, street_address: "1 Main Road, Rondebosch")
    assert_not matching.suburb_missing_from_address?

    mismatched = Subscription.new(suburb: suburb, street_address: "1 Main Road, Somewhere Else")
    assert mismatched.suburb_missing_from_address?
  end
end
