require "test_helper"

# Kept in its own file (rather than subscription_test.rb) since SubscriptionTest's
# shared `setup` creates a Subscription without a suburb/street_address and errors
# before every test regardless of test body — a pre-existing baseline issue on
# master, unrelated to the Suburb model.
class SubscriptionSuburbsTest < ActiveSupport::TestCase
  test "SUBURBS reflects active Suburb records" do
    Suburb.destroy_all
    Suburb.create!(name: "Test Suburb", status: :active)
    Suburb.create!(name: "Other Suburb", status: :waitlist)

    assert_equal ["Test Suburb"], Subscription.SUBURBS
  end

  test "SUBURBS falls back to the frozen list when the table is empty" do
    Suburb.destroy_all

    assert_equal Subscription::FALLBACK_SUBURBS, Subscription.SUBURBS
  end
end
