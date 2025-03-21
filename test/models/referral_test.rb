require "test_helper"

class ReferralTest < ActiveSupport::TestCase
  def setup
    @referrer = User.create!(email: "referrer@example.com", password: "password", referral_code: "REF123")
    @referee = User.create!(email: "referee@example.com", password: "password")
    @subscription = Subscription.create!(
      user: @referee,
      plan: "XL",
      duration: 3,
      street_address: "123 Street",
      suburb: "Cape Town"
    )
    @referral = Referral.new(
      referrer: @referrer,
      referee: @referee,
      subscription: @subscription
    )
  end

  test "should be valid with all associations" do
    assert @referral.valid?
  end

  test "should default to pending" do
    @referral.save
    assert_equal "pending", @referral.status
  end

  test "can transition to completed and used" do
    @referral.save
    @referral.completed!
    assert_equal "completed", @referral.status

    @referral.used!
    assert_equal "used", @referral.status
  end
end
